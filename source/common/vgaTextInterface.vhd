---------------------------------------------------------------------
--
--  Fichero:
--    vgaTextInterface.vhd  12/09/2023
--  test
--    (c) J.M. Mendias
--    Dise?o Autom芍tico de Sistemas
--    Facultad de Inform芍tica. Universidad Complutense de Madrid
--
--  Prop車sito:
--    Genera las se?ales de color y sincronismo de un interfaz texto
--    VGA con resoluci車n de 80x30 caracteres de 8x16 pixeles.
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

 component  vgaTextInterface_RAM IS
  PORT (
    clka : IN STD_LOGIC;
    wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    addra : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
    dina : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    clkb : IN STD_LOGIC;
    addrb : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
    doutb : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
  );
 END component;

 component vgaTextInterface_ROM
  PORT (
    clka : IN STD_LOGIC;
    addra : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
    douta : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
  );
 END component;

  constant COLSxLINE  : natural := 80;
  constant ROWSxFRAME : natural := 30;

  signal pixel : std_logic_vector (9 downto 0);
  signal line  : std_logic_vector (9 downto 0);

  signal colInt   : std_logic_vector (x'range);
  signal rowInt   : std_logic_vector (y'range);
  signal uColInt  : std_logic_vector (2 downto 0);
  signal uRowInt  : std_logic_vector (3 downto 0);
  
  -- SE?ALES NUEVAS DE RETARDO (DELAY) PARA SINCRONIZAR CON LAS BRAM
  signal uColInt_d1 : std_logic_vector (2 downto 0);
  signal uColInt_d2 : std_logic_vector (2 downto 0);
  signal uRowInt_d1 : std_logic_vector (3 downto 0);
  
  signal clearX : std_logic_vector(x'range) := (others => '0');
  signal clearY : std_logic_vector(y'range) := (others => '0');
  signal clearing : std_logic;
 
  signal color : std_logic_vector (11 downto 0);
 
  signal ramRdAddr, ramWrAddr : std_logic_vector (11 downto 0);
  signal we : std_logic;
  signal we_vector : std_logic_vector(0 downto 0);
  signal asciiCode, ramWrData : std_logic_vector (7 downto 0);
  
  signal romAddr     : std_logic_vector (11 downto 0);
  signal bitMapLine  : std_logic_vector (7 downto 0);
  signal bitMapPixel : std_logic;

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

  -- PROCESO DE SINCRONIZACI?N (Soluciona la imagen sucia)
  process(clk)
  begin
    if rising_edge(clk) then
      -- Retrasamos uColInt 2 ciclos de reloj (1 ciclo por RAM + 1 ciclo por ROM)
      uColInt_d1 <= uColInt;
      uColInt_d2 <= uColInt_d1;
      -- Retrasamos uRowInt 1 ciclo de reloj (1 ciclo por RAM)
      uRowInt_d1 <= uRowInt;
    end if;
  end process;

------------------  

 -- 1. Control de escritura
  we        <= '1' when (dataRdy = '1' or clearing = '1') else '0';
  we_vector(0) <= we;
  
 -- 2. Dato a escribir (X"00" es el espacio en blanco/vac赤o)
  ramWrData <= char when clearing = '0' else X"00";      
  
 -- 3. Direcci車n de escritura (concatenando y & x = 12 bits)
  ramWrAddr <= y & x when clearing = '0' else clearY & clearX;
  
 -- 4. Direcci車n de lectura para el VGA
  ramRdAddr <= rowInt & colInt;
  
   RAM:vgaTextInterface_RAM 
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
  
  -- USAMOS LA SE?AL RETRASADA (uRowInt_d1) para alinearnos con el asciiCode
  romAddr <= asciiCode & uRowInt_d1;
 
  ROM: vgaTextInterface_ROM 
    port map(
      clka  => clk,
      addra => romAddr,
      douta => bitMapLine
    );

------------------  

 -- USAMOS LA SE?AL RETRASADA (uColInt_d2) para alinearnos con bitMapLine
 with uColInt_d2 select
   bitMapPixel <= bitMapLine(7) when "000",
                  bitMapLine(6) when "001",
                  bitMapLine(5) when "010",
                  bitMapLine(4) when "011",
                  bitMapLine(3) when "100",
                  bitMapLine(2) when "101",
                  bitMapLine(1) when "110",
                  bitMapLine(0) when others;

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