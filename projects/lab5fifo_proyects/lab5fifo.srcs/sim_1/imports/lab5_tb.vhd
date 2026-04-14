---------------------------------------------------------------------
-- Testbench de loopback directo: receptor + transmisor (sin FIFO)
---------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity loopback_tb is
end loopback_tb;

architecture bench of loopback_tb is

  component rs232receiver
    generic (FREQ_KHZ : natural; BAUDRATE : natural);
    port (clk, rst : in std_logic; dataRdy : out std_logic;
          data : out std_logic_vector(7 downto 0); RxD : in std_logic);
  end component;

  component rs232transmitter
    generic (FREQ_KHZ : natural; BAUDRATE : natural);
    port (clk, rst : in std_logic; dataRdy : in std_logic;
          data : in std_logic_vector(7 downto 0); busy : out std_logic;
          TxD : out std_logic);
  end component;

  constant FREQ_KHZ : natural := 100000;
  constant BAUDRATE : natural := 9600;

  signal clk       : std_logic := '0';
  signal rst       : std_logic := '0';
  signal RxD       : std_logic := '1';        -- l¨ªnea de entrada al receptor
  signal TxD       : std_logic;                -- l¨ªnea de salida del transmisor
  signal dataRdyRx : std_logic;                -- dato listo del receptor
  signal dataRx    : std_logic_vector(7 downto 0);
  signal dataRdyTx : std_logic;                -- petici¨®n de env¨ªo al transmisor
  signal busyTx    : std_logic;

  constant clk_period  : time := 10 ns;
  constant baud_period : time := 104166 ns;

  -- Procedimiento para enviar un byte por RxD
  procedure send_rs232_byte (
    constant byte_val : in std_logic_vector(7 downto 0);
    signal rx_line    : out std_logic
  ) is
  begin
    report "   [TX] Enviando bit START (0)";
    rx_line <= '0';
    wait for baud_period;
    for i in 0 to 7 loop
      rx_line <= byte_val(i);
      wait for baud_period;
    end loop;
    rx_line <= '1';
    wait for baud_period;   -- bit STOP completo
  end procedure;

  -- Procedimiento para recibir un byte desde TxD
  procedure receive_rs232_byte (
    signal tx_line    : in std_logic;
    variable byte_val : out std_logic_vector(7 downto 0)
  ) is
  begin
    wait until falling_edge(tx_line);
    wait for baud_period / 2;
    for i in 0 to 7 loop
      wait for baud_period;
      byte_val(i) := tx_line;
    end loop;
    wait for baud_period;   -- esperar fin del stop
  end procedure;

begin

  -- Receptor
  receiver : rs232receiver
    generic map (FREQ_KHZ => FREQ_KHZ, BAUDRATE => BAUDRATE)
    port map (clk => clk, rst => rst, dataRdy => dataRdyRx,
              data => dataRx, RxD => RxD);

  -- Transmisor (conexi¨®n directa desde el receptor)
  dataRdyTx <= dataRdyRx;   -- en cuanto el receptor tiene un dato, lo env¨ªa

  transmitter : rs232transmitter
    generic map (FREQ_KHZ => FREQ_KHZ, BAUDRATE => BAUDRATE)
    port map (clk => clk, rst => rst, dataRdy => dataRdyTx,
              data => dataRx, busy => busyTx, TxD => TxD);

  clk_process : process
  begin
    clk <= '0'; wait for clk_period/2;
    clk <= '1'; wait for clk_period/2;
  end process;

  stim_proc: process
    variable rx_byte : std_logic_vector(7 downto 0);
  begin
    report "--- INICIANDO TEST DE LOOPBACK (SIN FIFO) ---";

    rst <= '1';
    wait for 100 ns;
    rst <= '0';
    wait for 200 ns;

    -- Enviar 0x41
    report "Enviando 0x41 por RxD...";
    send_rs232_byte(x"41", RxD);

    -- Esperar a que el transmisor termine de retransmitir
    wait until busyTx = '1';
    wait until busyTx = '0';

    -- Capturar el byte transmitido
    receive_rs232_byte(TxD, rx_byte);
    assert rx_byte = x"41" report "ERROR: 0x41 no coincide" severity failure;
    report "OK: 0x41 retransmitido correctamente";

    -- Enviar 0x5A
    report "Enviando 0x5A por RxD...";
    send_rs232_byte(x"5A", RxD);

    wait until busyTx = '1';
    wait until busyTx = '0';

    receive_rs232_byte(TxD, rx_byte);
    assert rx_byte = x"5A" report "ERROR: 0x5A no coincide" severity failure;
    report "OK: 0x5A retransmitido correctamente";

    report "-------------------------------------------------------";
    report "--- TEST FINALIZADO CON ?XITO ---";
    report "-------------------------------------------------------";
    wait;
  end process;

end bench;