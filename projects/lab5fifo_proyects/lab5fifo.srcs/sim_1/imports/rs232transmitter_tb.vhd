library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity rs232transmitter_tb is
end rs232transmitter_tb;

architecture bench of rs232transmitter_tb is

  component rs232transmitter
    generic (
      FREQ_KHZ : natural;
      BAUDRATE : natural
    );
    port (
      clk     : in  std_logic;
      rst     : in  std_logic;
      dataRdy : in  std_logic;
      data    : in  std_logic_vector (7 downto 0);
      busy    : out std_logic;
      TxD     : out std_logic
    );
  end component;

  constant FREQ_KHZ : natural := 100000; -- 100 MHz [cite: 183]
  constant BAUDRATE : natural := 9600;   -- [cite: 183]
  
  signal clk     : std_logic := '0';
  signal rst     : std_logic := '0';
  signal dataRdy : std_logic := '0';
  signal data    : std_logic_vector(7 downto 0) := (others => '0');
  signal busy    : std_logic;
  signal TxD     : std_logic;

  constant clk_period  : time := 10 ns;
  constant baud_period : time := 104166 ns; 

begin

  uut: rs232transmitter
    generic map ( FREQ_KHZ => FREQ_KHZ, BAUDRATE => BAUDRATE )
    port map ( clk => clk, rst => rst, dataRdy => dataRdy, data => data, busy => busy, TxD => TxD );

  clk_process : process
  begin
    clk <= '0'; wait for clk_period/2;
    clk <= '1'; wait for clk_period/2;
  end process;

  stim_proc: process
    variable captured_data : std_logic_vector(7 downto 0);
  begin		
    report "--- INICIANDO TEST DEL TRANSMISOR ---";
    rst <= '1';
    wait for 100 ns;
    rst <= '0';
    wait for 200 ns;

    -- FASE 1: Enviar 0x41 ('A')
    report "FASE 1: Solicitando transmision de 0x41...";
    data <= x"41"; 
    dataRdy <= '1'; 
    wait for clk_period;
    dataRdy <= '0';

    -- Monitorizacion de la linea TxD 
    wait until TxD = '0'; -- Esperar Bit de Start
    report "   [TXD] Bit de START detectado.";
    wait for baud_period / 2; -- Ir al centro del bit
    
    for i in 0 to 7 loop
        wait for baud_period;
        captured_data(i) := TxD;
        report "   [TXD] Muestreando bit " & integer'image(i) & ": " & std_logic'image(TxD);
    end loop;

    wait for baud_period;
    
    
    
    wait until busy = '0'; 
    report "--- TEST FINALIZADO CON EXITO ---";
    wait;
  end process;

end architecture;