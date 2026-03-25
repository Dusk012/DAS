-------------------------------------------------------------------
-- Ruta de datos del transmisor RS-232
-- (solo se帽ales std_logic y std_logic_vector, sin integer)
-------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity rs232transDatapath is
  generic (
    FREQ_KHZ : natural;  -- frecuencia del sistema en KHz
    BAUDRATE : natural   -- velocidad de comunicaci贸n en baudios
  );
  port (
    clk          : in  std_logic;
    rst          : in  std_logic;
    datapath     : in std_logic_vector(3 downto 0);
    data         : in  std_logic_vector(7 downto 0);  -- dato a transmitir
    writeTxD     : out std_logic;                      -- pulso de bit (tick)
    bitPosCntTC  : out std_logic;                      -- fin de cuenta 
    TxD          : out std_logic                       -- l铆nea serie
  );
end rs232transDatapath;

architecture Behavioral of rs232transDatapath is
  constant CYCLES_PER_BIT : natural := (FREQ_KHZ * 1000) / BAUDRATE;
  constant HALF_CYCLE     : natural := CYCLES_PER_BIT / 2;
  constant BAUD_CNT_WIDTH : natural := 32;

  signal baud_counter : unsigned(BAUD_CNT_WIDTH-1 downto 0) := (others => '0');
  signal shift_reg    : std_logic_vector(9 downto 0) := (others => '0');
  signal bit_counter  : unsigned(3 downto 0) := (others => '0');  -- 4 bits para 0..10

  signal ctrl: std_logic_vector(3 downto 0);
  alias TxDShfLD  : std_logic is ctrl(0);   -- carga del registro de desplazamiento
  alias TxDShfSH  : std_logic is ctrl(1);   -- desplazamiento del registro
  alias baudCntCE : std_logic is ctrl(2);   -- habilita el contador de baudios
  alias bitPosCntCE : std_logic is ctrl(3); -- habilita el contador de bits
begin
    ctrl <= datapath;

  -- Contador de baudios
  baudCnt : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        baud_counter <= (others => '0');
      elsif baudCntCE = '1' then
        if baud_counter = CYCLES_PER_BIT - 1 then
          baud_counter <= (others => '0');
        else
          baud_counter <= baud_counter + 1;
        end if;
      end if;
    end if;
  end process;

  writeTxD <= '1' when (baudCntCE = '1' and baud_counter = HALF_CYCLE - 1) else '0';

  -- Registro de desplazamiento
  RSHIFTER : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        shift_reg <= (others => '1');
      else
        if TxDShfLD = '1' then
          shift_reg <= '1' & data & '0';   -- stop & data & start
        elsif TxDShfSH = '1' then
          shift_reg <= '1' & shift_reg(9 downto 1);  -- desplaza e introduce '1'
        end if;
      end if;
    end if;
  end process;

  TxD <= shift_reg(0);

  -- Contador de estados (m贸dulo 11: 0..10)
  bitPosCnt : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        bit_counter <= (others => '0');
      elsif bitPosCntCE = '1' then
        if bit_counter = 10 then
          bit_counter <= (others => '0');
        else
          bit_counter <= bit_counter + 1;
        end if;
      end if;
    end if;
  end process;
--begin
    --if rising_edge(clk) then
      --if rst = '1' then
        --bit_counter <= (others => '0');
      --elsif writeTxD_int = '1' then  
        --if bit_counter = 10 then
          --bit_counter <= (others => '0');
        --else
          --bit_counter <= bit_counter + 1;
        --end if;
      --end if;
    --end if;
  --end process;
  bitPosCntTC <= '1' when bit_counter = 10 and bitPosCntCE = '1' else '0';

end Behavioral;