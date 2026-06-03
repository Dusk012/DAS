-------------------------------------------------------------------
--
--  Fichero:
--    ov7670colorReader.vhd  08/06/2023
--
--    (c) J.M. Mendias
--    Diseo Automtico de Sistemas
--    Facultad de Informtica. Universidad Complutense de Madrid
--
--  Propsito:
--    Captura vdeo desde una camara ov7670
--
--  Notas de diseo:
--    - tamao VGA, modo RGB 4:4:4
--
-------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity ov7670reader is
  port ( 
    -- host side
    clk      : in  std_logic;  -- reloj del sistema    
    rec      : in  std_logic;  -- captura video mientras esta activa
    -- frame buffer side
    y        : out std_logic_vector (8 downto 0);    -- coordenada vertical del pixel (0: arriba)
    x        : out std_logic_vector (9 downto 0);    -- coordenada horizontal del pixel (0: izquierda)
    dataRdy  : out std_logic;                        -- se activa durante 1 ciclo cada vez que ha recibido un nuevo pixel
    data     : out std_logic_vector (11 downto 0);   -- color del pixel recibido
    frameRdy : out std_logic;                        -- se activa durante 1 ciclo cada vez que ha recibido una nueva frame
    -- ov7670 video side
    pclk     : in  std_logic;                        -- reloj de pixel
    cvSync   : in  std_logic;                        -- sincronizacion vertical
    href     : in  std_logic;                        -- se activa durante la transmisin de un frame horizontal
    cData    : in  std_logic_vector (7 downto 0)     -- muestra recibida del sensor de imagen   
  );
end ov7670reader;

---------------------------------------------------------------------

library ieee;
use ieee.numeric_std.all;
use work.common.all;

architecture syn of ov7670reader is
        
  signal cDataD     : std_logic_vector (7 downto 0); 
  signal pclkD      : std_logic;
  signal hrefD      : std_logic;
  signal pclkRise   : std_logic;
  signal cvSyncRise : std_logic; 
  
  -- Se?ales del proceso inputsDelayer
  signal aux0       : std_logic_vector (8 downto 0) := (others => '0');
  signal aux1       : std_logic_vector (8 downto 0) := (others => '0');

  -- Se?ales del proceso reader
  signal nibble     : std_logic_vector(3 downto 0)  := (others => '0');
  signal byteCnt    : unsigned(10 downto 0)         := (others => '0');
  signal lineCnt    : unsigned(8 downto 0)          := (others => '0');
  signal lineCntCE  : std_logic := '0';

  -- NUEVA SE?AL INTERNA para solucionar el error de lectura del puerto OUT
  signal frameRdy_s : std_logic;

begin
  
  -- Extraemos estas asignaciones fuera del proceso para mantener la limpieza
  hrefD  <= aux1(8);
  cDataD <= aux1(7 downto 0);

  inputsDelayer:
  process ( clk )
  begin 
    if rising_edge(clk) then
      aux1 <= aux0;
      aux0 <= href & cData;
    end if;
  end process;
  
  pclkEdgeDetector : edgeDetector
    generic map ( XPOL => '0' )
    port map ( clk => clk, x => pclk, xFall => open, xRise => pclkRise );
  
  cvSyncEdgeDetector : edgeDetector
    generic map ( XPOL => '0' )
    port map ( clk => clk, x => cvSync, xFall => open, xRise => cvSyncRise );
    
  -- Asignamos a la se?al interna y luego volcamos al puerto OUT
  frameRdy_s <= cvSyncRise and rec;
  frameRdy   <= frameRdy_s;

  pclkD <= pclkRise and rec and hrefD;
  
  contador_byteCnt:
  process(clk)
  begin
  if rising_edge(clk) then
    lineCntCE <= '0';
    -- Usamos la se?al interna frameRdy_s en lugar del puerto de salida frameRdy
    if frameRdy_s = '1' then
      byteCnt <= (others => '0');
    elsif pclkD = '1' then 
      if byteCnt = (2 * 640) -1 then  
        byteCnt <= (others => '0');
        lineCntCE <= '1';
      else 
        byteCnt <= byteCnt + 1;       
      end if;
    end if;
  end if;
  end process;

  contador_lineCnt:
  process(clk)
  begin
  if rising_edge(clk) then
    -- Usamos la se?al interna frameRdy_s en lugar del puerto de salida frameRdy
    if frameRdy_s = '1' then
      lineCnt <= (others => '0');
    elsif lineCntCE= '1' then 
      if lineCnt = 480 -1 then  
        lineCnt <= (others => '0');
      else 
        lineCnt <= lineCnt + 1;
      end if;
    end if;
  end if;
  end process;

  registerNibble:
  process(clk)
  begin
  if rising_edge(clk) then
    -- Solo generamos un pulso de 'dataRdy' que dura 1 ciclo cuando llega el byte impar
    dataRdy <= '0'; 

    -- Usamos la se?al interna frameRdy_s en lugar del puerto de salida frameRdy
    if frameRdy_s = '1' then
      nibble <= (others => '0');
    elsif pclkD = '1' then 
      -- Si es el byte par (primer byte), guardamos el nibble y NO enviamos dato
      if byteCnt(0) = '0' then
        nibble <= cDataD(3 downto 0);
      else
      -- Si es el byte impar (segundo byte), reportamos que el pixel est¨¢ listo
        dataRdy <= '1';
      end if;
    end if;
  end if;
  end process;

  -- Asignaci¨®n de las salidas continuas que faltaban
  x    <= std_logic_vector(byteCnt(10 downto 1));
  y    <= std_logic_vector(lineCnt);
  data <= nibble & cDataD;

end syn;