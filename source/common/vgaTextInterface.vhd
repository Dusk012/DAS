---------------------------------------------------------------------
--
--  Fichero:
--    vgaTextInterface.vhd  12/09/2023
--  test
--    (c) J.M. Mendias
--    Diseño Automático de Sistemas
--    Facultad de Informática. Universidad Complutense de Madrid
--
--  Propósito:
--    Genera las señales de color y sincronismo de un interfaz texto
--    VGA con resolución de 80x30 caracteres de 8x16 pixeles.
--
--  Notas de diseño:
--    - Para frecuencias a partir de 50 Mhz en multiplos de 25 MHz
--    - Incluye una memoria de refresco para almacenar los caracteres
--      a visualizar y una memoria de mapas de bits de cada caracter 
--
---------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity vgaTextInterface is
  generic(
    FREQ_DIV : natural;  -- valor por el que dividir la frecuencia del reloj del sistema para obtener 25 MHz
    BGCOLOR  : std_logic_vector (11 downto 0); -- color del background
    FGCOLOR  : std_logic_vector (11 downto 0)  -- color del foreground
  );
  port ( 
    -- host side
    clk     : in std_logic;   -- reloj del sistema
    clear   : in std_logic;   -- borra la memoria de refresco
    dataRdy : in std_logic;   -- se activa durante 1 ciclo cada vez que hay un nuevo caracter a visualizar
    char    : in std_logic_vector (7 downto 0);   -- codigo ASCII del caracter a visualizar
    x       : in std_logic_vector (6 downto 0);   -- columna en donde visualizar el caracter
    y       : in std_logic_vector (4 downto 0);   -- fila en donde visualizar el caracter
    --
    col     : out std_logic_vector (6 downto 0);   -- numero de columna que se esta barriendo
    uCol    : out std_logic_vector (2 downto 0);   -- numero de microcolumna que se esta barriendo
    row     : out std_logic_vector (4 downto 0);   -- numero de fila que se esta barriendo
    uRow    : out std_logic_vector (3 downto 0);   -- numero de microfila que se esta barriendo
    -- VGA side
    hSync  : out std_logic;   -- sincronizacion horizontal
    vSync  : out std_logic;   -- sincronizacion vertical
    RGB    : out std_logic_vector (11 downto 0)   -- canales de color
  );
end vgaTextInterface;

---------------------------------------------------------------------

library ieee;
use ieee.numeric_std.all;
use work.common.all;

architecture syn of vgaTextInterface is

 

 

  constant COLSxLINE  : natural := 80;
  constant ROWSxFRAME : natural := 30;

  signal pixel : std_logic_vector (9 downto 0);
  signal line  : std_logic_vector (9 downto 0);

  signal colInt   : std_logic_vector (x'range);
  signal rowInt   : std_logic_vector (y'range);
  signal uColInt  : std_logic_vector (2 downto 0);
  signal uRowInt  : std_logic_vector (3 downto 0);
  
  signal clearX : std_logic_vector(x'range) := (others => '0');
  signal clearY : std_logic_vector(y'range) := (others => '0');
  signal clearing : std_logic;
 
  signal color : std_logic_vector (11 downto 0);
 
  signal ramRdAddr, ramWrAddr : std_logic_vector (11 downto 0);
  signal we : std_logic;
  signal we_vector : std_logic_vector(0 downto 0);
  signal asciiCode, ramWrData : std_logic_vector (7 downto 0);
  
  type   ramType is array (0 to 2**(x'length+y'length)-1) of std_logic_vector (char'range);
  signal ram : ramType;
  
  signal romAddr     : std_logic_vector (11 downto 0);
  signal bitMapLine  : std_logic_vector (7 downto 0);
  signal bitMapPixel : std_logic;

  type   romType is array (0 to 2**12-1) of std_logic_vector (7 downto 0);  -- OJO: los pixeles están ubicados de izq. a der. y da igual que se cambie el range
  signal rom : romType := ();

begin
  screenInteface: vgaRefresher
    generic map ( FREQ_DIV => FREQ_DIV )
    port map 
    ( clk => clk, 
      line => line, 
      pixel => pixel, 
      R => color(11 downto 8), 
      G => color(7 downto 4), 
      B => color(3 downto 0), 
      hSync => hSync, 
      vSync => vSync, 
      RGB => RGB );
  
  colInt  <= pixel(9 downto 3);
  uColInt <= pixel(2 downto 0);
  
  rowInt  <= line(8 downto 4);
  uRowInt <= line(3 downto 0);
  
  col  <= colInt;
  uCol <= uColInt;
  
  row  <= rowInt;
  uRow <= uRowInt;
  
------------------  

 -- 1. Control de escritura
  we        <= '1' when (dataRdy = '1' or clearing = '1') else '0';
  we_vector(0) <= we;
  -- 2. Dato a escribir (X"00" es el espacio en blanco/vacío)
  ramWrData <= char when clearing = '0' else X"00";      
  
  -- 3. Dirección de escritura (concatenando y & x = 12 bits)
  ramWrAddr <= y & x when clearing = '0' else clearY & clearX;
  
  -- 4. Dirección de lectura para el VGA
  ramRdAddr <= rowInt & colInt;
  
  -- El RAM ahora es una IP, ya no es necesario el proceso original
  --process (clk)
  --begin
    --if rising_edge(clk) then
      --if we='1' then
        --ram( ... ) <= ...;
      --end if; 
      --asciiCode <= ram( ... );
    --end if;
  --end process;

   RAM: entity work.vgaTextInterface_RAM is 
    port map(
      clka  => clk,
      wea   => we_vector,
      addra => ramWrAddr,
      dina  => ramWrData,
      clkb  => clk,
      addrb => ramRdAddr,
      doutb => asciiCode
    );

------------------  
  
  romAddr <= asciiCode & uRowInt;
 
  -- El ROM ahora es una IP, ya no es necesario el proceso original
  --process (clk)
  --begin
    --if rising_edge(clk) then
      --bitMapLine <= rom( ... ) ;
    --end if;
  --end process;

  ROM: entity work.vgaTextInterface_ROM is
    port map(
      clka  => clk,
      addra => romAddr,
      douta => bitMapLine
    );

------------------  

 with uColInt select
   bitMapPixel <= bitMapLine(0) when "000",
                  bitMapLine(1) when "001",
                  bitMapLine(2) when "010",
                  bitMapLine(3) when "011",
                  bitMapLine(4) when "100",
                  bitMapLine(5) when "101",
                  bitMapLine(6) when "110",
                  bitMapLine(7) when others;

color <= FGCOLOR when bitMapPixel = '1' else BGCOLOR;
  
------------------  

clearCounters:
process (clk, clear)
begin
   if clear = '1' then
      clearing <= '1';
      clearX   <= (others => '0');
      clearY   <= (others => '0');
   elsif rising_edge(clk) then
      if clearing = '1' then
         if clearX = std_logic_vector(to_unsigned(COLSxLINE - 1, clearX'length)) then
            clearX <= (others => '0');
            if clearY = std_logic_vector(to_unsigned(ROWSxFRAME - 1, clearY'length)) then
               clearing <= '0';
            else
               clearY <= std_logic_vector(unsigned(clearY) + 1);
            end if;
         else
            clearX <= std_logic_vector(unsigned(clearX) + 1);
         end if;
      end if;
   end if;
end process;


end syn;
