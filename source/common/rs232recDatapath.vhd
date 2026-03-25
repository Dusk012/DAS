library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity rs232recDatapath is
  generic (
    FREQ_KHZ : natural;  -- frecuencia del sistema en KHz
    BAUDRATE : natural   -- velocidad de comunicaci贸n
  );
  port (
    clk          : in  std_logic;
    rst          : in  std_logic;
    RxDSync      : in  std_logic;                    
    datapath     : in  std_logic_vector(2 downto 0); -- control: (baudCntCE, bitPosCntCE)
    readRxD      : out std_logic;                     -- pulso de muestreo (mitad de bit)
    bitPosCntTC  : out std_logic;                     -- fin de cuenta (bit 10)
    data         : out std_logic_vector(7 downto 0)   -- dato recibido
  );
end rs232recDatapath;

architecture Behavioral of rs232recDatapath is
  constant CYCLES_PER_BIT : natural := (FREQ_KHZ * 1000) / BAUDRATE;
  constant HALF_CYCLE      : natural := CYCLES_PER_BIT / 2;
  constant BAUD_CNT_WIDTH  : natural := 32;   -- ancho suficiente

  signal baud_counter : unsigned(BAUD_CNT_WIDTH-1 downto 0) := (others => '0');
  signal readRxD_int  : std_logic;
  signal rx_shift     : std_logic_vector(9 downto 0) := (others => '0');  -- registro de 10 bits
  signal bit_counter  : unsigned(3 downto 0) := (others => '0');          -- 0..10
  --signal RxDSync      : std_logic;

  signal ctrl : std_logic_vector(2 downto 0);
  alias baudCntCE    : std_logic is ctrl(0);
  alias bitPosCntCE : std_logic is ctrl(1);
  alias RxDShfSH : std_logic is ctrl(2);

begin

  ctrl <= datapath;

  -- Contador de baudios: genera readRxD a mitad del per铆odo de bit
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
      else
        baud_counter <= (others => '0');
      end if;
    end if;
  end process;

  readRxD <= '1' when (baudCntCE = '1' and baud_counter = HALF_CYCLE - 1) else '0';


  -- Registro de desplazamiento de 10 bits (desplazamiento a la derecha, entrada por la izquierda)
  shift_proc : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        rx_shift <= (others => '0');
      elsif RxDShfSH = '1' then
        rx_shift <= RxDSync & rx_shift(9 downto 1);
      end if;
    end if;
  end process;
   -- Los datos se toman de las posiciones 8..1 del registro (despu茅s del stop)
  data <= rx_shift(8 downto 1);

  -- Contador de bits (0..10)
  bit_counter_proc : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        bit_counter <= (others => '0');
      elsif bitPosCntCE = '1' then
        if bit_counter = 10 then
          bit_counter <= (others => '0');   -- vuelve a 0 
        else
          bit_counter <= bit_counter + 1;
        end if;
      end if;
    end if;
  end process;

  bitPosCntTC <= '1' when bit_counter = 10 and bitPosCntCE = '1'  else '0';

 
end Behavioral;