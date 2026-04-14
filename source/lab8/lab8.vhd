---------------------------------------------------------------------
--
--  Fichero:
--    lab8.vhd  12/09/2023
--
--    (c) J.M. Mendias
--    Diseño Automático de Sistemas
--    Facultad de Informática. Universidad Complutense de Madrid
--
--  Propósito:
--    Laboratorio 8
--
--  Notas de diseño:
--
---------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity lab8 is
  port ( 
    clk     : in  std_logic;
    rst     : in  std_logic;
    ps2Clk  : in  std_logic;
    ps2Data : in  std_logic;
    hSync   : out std_logic;
    vSync   : out std_logic;
    RGB     : out std_logic_vector(11 downto 0)
  );
end lab8;

---------------------------------------------------------------------

library ieee;
use ieee.numeric_std.all;
use work.common.all;

architecture syn of lab8 is

  constant FREQ_KHZ : natural := 100_000;  -- frecuencia de operacion en KHz
  constant VGA_KHZ  : natural := 25_000;   -- frecuencia de envio de pixeles a la VGA en KHz
  constant FREQ_DIV : natural := FREQ_KHZ/VGA_KHZ; 

  constant COLSxLINE  : natural := 80;
  constant ROWSxFRAME : natural := 30;

  constant BGCOLOR : std_logic_vector( RGB'range ) := "000000000000";   -- Fondo negro
  constant FGCOLOR : std_logic_vector( RGB'range ) := "000011110000";   -- Letras verdes

  signal rstSync : std_logic;
  
  signal key     : std_logic_vector (7 downto 0);
  signal keyRdy : std_logic;

  signal x : unsigned (log2(COLSxLINE)-1 downto 0)  := (others => '0');
  signal y : unsigned (log2(ROWSxFRAME)-1 downto 0) := (others => '0');
   
  signal col    : std_logic_vector (x'range);
  signal row    : std_logic_vector (y'range);
  signal uRow   : std_logic_vector (3 downto 0);
  signal RGBinterface : std_logic_vector (RGB'range);
  
  signal shiftP, capsOn : boolean := false;
  
  signal char : std_logic_vector (7 downto 0) := (others => '0');
  signal charRdy : std_logic := '0';

  signal asciiCode : std_logic_vector (7 downto 0);
  
  signal clear, newLine : std_logic := '0';

  signal romAddr : std_logic_vector (8 downto 0);
  
  type   romType is array (0 to 2**9-1) of std_logic_vector (7 downto 0);
  signal rom : romType := ( 
    --------------------------------------------------------------------------------  minusculas
    X"7f", X"7f", X"7f", X"7f", X"7f", X"7f", X"7f", X"7f",    -- 0x00 ... 0x07: _ _ _ _ _ _ _ _
    X"7f", X"7f", X"7f", X"7f", X"7f", X"7f", X"7f", X"7f",    -- 0x08 ... 0x0F: _ _ _ _ _ _ _ _
    X"7f", X"7f", X"7f", X"7f", X"7f", X"71", X"31", X"7f",    -- 0x10 ... 0x17: _ _ _ _ _ q 1 _
    X"7f", X"7f", X"7a", X"73", X"61", X"77", X"32", X"7f",    -- 0x18 ... 0x1F: _ _ z s a w 2 _
    X"7f", X"63", X"78", X"64", X"65", X"34", X"33", X"7f",    -- 0x20 ... 0x27: _ c x d e 4 3 _
    X"7f", X"20", X"76", X"66", X"74", X"72", X"35", X"7f",    -- 0x28 ... 0x2F: _   v f t r 5 _
    X"7f", X"6e", X"62", X"68", X"67", X"79", X"36", X"7f",    -- 0x30 ... 0x37: _ n b h g y 6 _
    X"7f", X"7f", X"6d", X"6a", X"75", X"37", X"38", X"7f",    -- 0x38 ... 0x3F: _ _ m j u 7 8 _    
    X"7f", X"2c", X"6b", X"69", X"6f", X"30", X"39", X"7f",    -- 0x40 ... 0x47: _ , k i o 0 9 _
    X"7f", X"2e", X"2d", X"6c", X"a4", X"70", X"27", X"7f",    -- 0x48 ... 0x4F: _ . - l ñ p ' _    
    X"7f", X"7f", X"b4", X"7f", X"60", X"a1", X"7f", X"7f",    -- 0x50 ... 0x57: _ _ ´ _ ` ¡ _ _
    X"7f", X"7f", X"7f", X"2b", X"7f", X"7f", X"7f", X"7f",    -- 0x58 ... 0x5F: _ _ _ + _ _ _ _    
    X"7f", X"7f", X"7f", X"7f", X"7f", X"7f", X"7f", X"7f",    -- 0x60 ... 0x67: _ _ _ _ _ _ _ _
    X"7f", X"31", X"7f", X"34", X"37", X"7f", X"7f", X"7f",    -- 0x68 ... 0x6F: _ 1 _ 4 7 _ _ _
    X"30", X"2e", X"32", X"35", X"36", X"38", X"7f", X"7f",    -- 0x70 ... 0x77: 0 . 2 5 6 8 _ _
    X"7f", X"2b", X"33", X"2d", X"2a", X"39", X"7f", X"7f",    -- 0x78 ... 0x7F: _ + 3 - * 9 _ _
    X"7f", X"7f", X"7f", X"7f", X"7f", X"7f", X"7f", X"7f",    -- 0x80 ... 0x87: _ _ _ _ _ _ _ _
    X"7f", X"7f", X"7f", X"7f", X"7f", X"7f", X"7f", X"7f",    -- 0x88 ... 0x8F: _ _ _ _ _ _ _ _
    X"7f", X"7f", X"7f", X"7f", X"7f", X"7f", X"7f", X"7f",    -- 0x90 ... 0x97: _ _ _ _ _ _ _ _
    X"7f", X"7f", X"7f", X"7f", X"7f", X"7f", X"7f", X"7f",    -- 0x98 ... 0x9F: _ _ _ _ _ _ _ _
    X"7f", X"7f", X"7f", X"7f", X"7f", X"7f", X"7f", X"7f",    -- 0xA0 ... 0xA7: _ _ _ _ _ _ _ _
    X"7f", X"7f", X"7f", X"7f", X"7f", X"7f", X"7f", X"7f",    -- 0xA8 ... 0xAF: _ _ _ _ _ _ _ _
    X"7f", X"7f", X"7f", X"7f", X"7f", X"7f", X"7f", X"7f",    -- 0xB0 ... 0xB7: _ _ _ _ _ _ _ _
    X"7f", X"7f", X"7f", X"7f", X"7f", X"7f", X"7f", X"7f",    -- 0xB8 ... 0xBF: _ _ _ _ _ _ _ _
    X"7f", X"7f", X"7f", X"7f", X"7f", X"7f", X"7f", X"7f",    -- 0xC8 ... 0xCF: _ _ _ _ _ _ _ _
    X"7f", X"7f", X"7f", X"7f", X"7f", X"7f", X"7f", X"7f",    -- 0xC8 ... 0xCF: _ _ _ _ _ _ _ _
    X"7f", X"7f", X"7f", X"7f", X"7f", X"7f", X"7f", X"7f",    -- 0xD8 ... 0xDF: _ _ _ _ _ _ _ _
    X"7f", X"7f", X"7f", X"7f", X"7f", X"7f", X"7f", X"7f",    -- 0xD8 ... 0xDF: _ _ _ _ _ _ _ _
    X"7f", X"7f", X"7f", X"7f", X"7f", X"7f", X"7f", X"7f",    -- 0xE8 ... 0xEF: _ _ _ _ _ _ _ _
    X"7f", X"7f", X"7f", X"7f", X"7f", X"7f", X"7f", X"7f",    -- 0xE8 ... 0xEF: _ _ _ _ _ _ _ _
    X"7f", X"7f", X"7f", X"7f", X"7f", X"7f", X"7f", X"7f",    -- 0xF8 ... 0xFF: _ _ _ _ _ _ _ _
    X"7f", X"7f", X"7f", X"7f", X"7f", X"7f", X"7f", X"7f",    -- 0xF8 ... 0xFF: _ _ _ _ _ _ _ _
    --------------------------------------------------------------------------------  mayusculas    
    X"7f", X"7f", X"7f", X"7f", X"7f", X"7f", X"7f", X"7f",    -- 0x00 ... 0x07: _ _ _ _ _ _ _ _
    X"7f", X"7f", X"7f", X"7f", X"7f", X"7f", X"7f", X"7f",    -- 0x08 ... 0x0F: _ _ _ _ _ _ _ _
    X"7f", X"7f", X"7f", X"7f", X"7f", X"51", X"21", X"7f",    -- 0x10 ... 0x17: _ _ _ _ _ Q ! _
    X"7f", X"7f", X"5a", X"53", X"41", X"57", X"22", X"7f",    -- 0x18 ... 0x1F: _ _ Z S A W " _
    X"7f", X"43", X"58", X"44", X"45", X"24", X"b7", X"7f",    -- 0x20 ... 0x27: _ C X D E $ · _
    X"7f", X"20", X"56", X"46", X"54", X"52", X"25", X"7f",    -- 0x28 ... 0x2F: _   V F T R % _
    X"7f", X"4e", X"42", X"48", X"47", X"59", X"26", X"7f",    -- 0x30 ... 0x37: _ N B H G Y & _
    X"7f", X"7f", X"4d", X"4a", X"55", X"2f", X"28", X"7f",    -- 0x38 ... 0x3F: _ _ M J U / ( _    
    X"7f", X"3b", X"4b", X"49", X"4f", X"3d", X"29", X"7f",    -- 0x40 ... 0x47: _ ; K I O = ) _
    X"7f", X"3a", X"5f", X"4c", X"a5", X"50", X"3f", X"7f",    -- 0x48 ... 0x4F: _ : _ L Ñ P ? _    
    X"7f", X"7f", X"a8", X"7f", X"5e", X"bf", X"7f", X"7f",    -- 0x50 ... 0x57: _ _ ¨ _ ^ ¿ _ _
    X"7f", X"7f", X"7f", X"2a", X"7f", X"7f", X"7f", X"7f",    -- 0x58 ... 0x5F: _ _ _ * _ _ _ _    
    X"7f", X"7f", X"7f", X"7f", X"7f", X"7f", X"7f", X"7f",    -- 0x60 ... 0x67: _ _ _ _ _ _ _ _
    X"7f", X"31", X"7f", X"34", X"37", X"7f", X"7f", X"7f",    -- 0x68 ... 0x6F: _ 1 _ 4 7 _ _ _
    X"30", X"2e", X"32", X"35", X"36", X"38", X"7f", X"7f",    -- 0x70 ... 0x77: 0 . 2 5 6 8 _ _
    X"7f", X"2b", X"33", X"2d", X"2a", X"39", X"7f", X"7f",    -- 0x78 ... 0x7F: _ + 3 - * 9 _ _
    X"7f", X"7f", X"7f", X"7f", X"7f", X"7f", X"7f", X"7f",    -- 0x80 ... 0x87: _ _ _ _ _ _ _ _
    X"7f", X"7f", X"7f", X"7f", X"7f", X"7f", X"7f", X"7f",    -- 0x88 ... 0x8F: _ _ _ _ _ _ _ _
    X"7f", X"7f", X"7f", X"7f", X"7f", X"7f", X"7f", X"7f",    -- 0x90 ... 0x97: _ _ _ _ _ _ _ _
    X"7f", X"7f", X"7f", X"7f", X"7f", X"7f", X"7f", X"7f",    -- 0x98 ... 0x9F: _ _ _ _ _ _ _ _
    X"7f", X"7f", X"7f", X"7f", X"7f", X"7f", X"7f", X"7f",    -- 0xA0 ... 0xA7: _ _ _ _ _ _ _ _
    X"7f", X"7f", X"7f", X"7f", X"7f", X"7f", X"7f", X"7f",    -- 0xA8 ... 0xAF: _ _ _ _ _ _ _ _
    X"7f", X"7f", X"7f", X"7f", X"7f", X"7f", X"7f", X"7f",    -- 0xB0 ... 0xB7: _ _ _ _ _ _ _ _
    X"7f", X"7f", X"7f", X"7f", X"7f", X"7f", X"7f", X"7f",    -- 0xB8 ... 0xBF: _ _ _ _ _ _ _ _
    X"7f", X"7f", X"7f", X"7f", X"7f", X"7f", X"7f", X"7f",    -- 0xC8 ... 0xCF: _ _ _ _ _ _ _ _
    X"7f", X"7f", X"7f", X"7f", X"7f", X"7f", X"7f", X"7f",    -- 0xC8 ... 0xCF: _ _ _ _ _ _ _ _
    X"7f", X"7f", X"7f", X"7f", X"7f", X"7f", X"7f", X"7f",    -- 0xD8 ... 0xDF: _ _ _ _ _ _ _ _
    X"7f", X"7f", X"7f", X"7f", X"7f", X"7f", X"7f", X"7f",    -- 0xD8 ... 0xDF: _ _ _ _ _ _ _ _
    X"7f", X"7f", X"7f", X"7f", X"7f", X"7f", X"7f", X"7f",    -- 0xE8 ... 0xEF: _ _ _ _ _ _ _ _
    X"7f", X"7f", X"7f", X"7f", X"7f", X"7f", X"7f", X"7f",    -- 0xE8 ... 0xEF: _ _ _ _ _ _ _ _
    X"7f", X"7f", X"7f", X"7f", X"7f", X"7f", X"7f", X"7f",    -- 0xF8 ... 0xFF: _ _ _ _ _ _ _ _
    X"7f", X"7f", X"7f", X"7f", X"7f", X"7f", X"7f", X"7f"     -- 0xF8 ... 0xFF: _ _ _ _ _ _ _ _
  );
  
begin
 
  rstSynchronizer : synchronizer
    generic map ( STAGES => 2, XPOL => '0' )
    port map ( clk => clk, x => rst, xSync => rstSync );

  ------------------  
  
  ps2KeyboardInterface : ps2receiver
    port map ( clk => clk, rst => rstSync, dataRdy => keyRdy, data => key, ps2Clk => ps2Clk, ps2Data => ps2Data ); 
       
  keyScanner:
  process (clk)
    type states is (keyON, keyOFF);
    variable state : states := keyON;
  begin
    if rising_edge(clk) then
      if rstSync='1' then
        state  := keyOn;
        shiftP <= false;
        capsOn <= false;
        charRdy <= '0';
        newLine <= '0';
        clear   <= '0';
      else
        ...
        if keyRdy='1' then
          case state is
            ...
          end case;
        end if;
      end if;
    end if;
  end process;    

  ------------------  

  romAddr <= ...;

  asciiCode <= rom( ... );  
    
  ------------------     
  
  xCounter:
  process (clk)
  begin
    ...
  end process;
  
  yCounter:
  process (clk)
  begin
    ...
  end process;
  
  ------------------     

  screenInterface: vgaTextInterface 
    generic map ( FREQ_DIV => FREQ_DIV, BGCOLOR => BGCOLOR, FGCOLOR => FGCOLOR )
    port map ( clk => clk, clear => clear, x => std_logic_vector(x), y => std_logic_vector(y), char => char, charRdy => charRdy, col => col, uCol => open, row => row, uRow => uRow, hSync => hSync, vSync => vSync, RGB => RGBinterface );
      
 ------------------     

  cursorRender:
  process (row, col, uRow, x, y)
  begin
    RGB <= RGBinterface;
    if ... then
      ...
    end if;
  end process;
  
end syn;

