---------------------------------------------------------------------
-- Testbench para el sistema lab5fifo (receptor + FIFO + transmisor)
---------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity lab5fifo_tb is
end lab5fifo_tb;

architecture bench of lab5fifo_tb is

  -- Componente a testear (dise?o principal)
  component lab5loopback
    port (
      clk :  in std_logic;
    rst :  in std_logic;
    RxD :  in std_logic; 
    TxD : out std_logic
    );
  end component;

  -- Constantes de configuraci¨®n (seg¨²n lab5fifo.vhd)
  constant FREQ_KHZ : natural := 100000;          -- 100 MHz
  constant BAUDRATE : natural := 1200;            -- 1200 baudios

  -- Per¨ªodos de tiempo
  constant clk_period  : time := 10 ns;           -- 100 MHz
  constant baud_period : time := 833_334 ns;      -- 1/1200 s ¡Ö 833,33 ?s

  -- Se?ales de interconexi¨®n
  signal clk    : std_logic := '0';
  signal rst    : std_logic := '0';
  signal RxD    : std_logic := '1';               -- reposo
  signal TxD    : std_logic;


  -----------------------------------------------------------------
  -- Procedimiento para enviar un byte por la l¨ªnea RxD
  -----------------------------------------------------------------
  procedure send_rs232_byte (
    constant byte_val : in std_logic_vector(7 downto 0);
    signal rx_line    : out std_logic
  ) is
  begin
    report "   [TB] Enviando bit START (0)";
    rx_line <= '0';
    wait for baud_period;

    for i in 0 to 7 loop
      report "   [TB] Enviando bit " & integer'image(i) & ": " & std_logic'image(byte_val(i));
      rx_line <= byte_val(i);
      wait for baud_period;
    end loop;

    report "   [TB] Enviando bit STOP (1)";
    rx_line <= '1';
    wait for baud_period;   -- espera el bit de stop completo
  end procedure;

  -----------------------------------------------------------------
  -- Procedimiento para recibir un byte desde la l¨ªnea TxD
  -----------------------------------------------------------------
  procedure receive_rs232_byte (
    signal tx_line    : in std_logic;
    variable byte_val : out std_logic_vector(7 downto 0)
  ) is
  begin
    -- Esperar el flanco de bajada (bit de START)
    wait until falling_edge(tx_line);
    report "   [TB] Detectado bit START";

    -- Esperar hasta la mitad del per¨ªodo para muestrear
    wait for baud_period / 2;

    -- Leer los 8 bits de datos (LSB primero)
    for i in 0 to 7 loop
      wait for baud_period;   -- ir al centro del siguiente bit
      byte_val(i) := tx_line;
      report "   [TB] Muestreando bit " & integer'image(i) & ": " & std_logic'image(tx_line);
    end loop;

    -- Esperar a que termine el bit de STOP
    wait for baud_period;
  end procedure;

begin

  -- Instancia del dise?o principal
  uut: lab5loopback
    port map (
      clk    => clk,
      rst    => rst,
      RxD    => RxD,
      TxD    => TxD
    );

  -----------------------------------------------------------------
  -- Generador de reloj
  -----------------------------------------------------------------
  clk_process : process
  begin
    clk <= '0';
    wait for clk_period/2;
    clk <= '1';
    wait for clk_period/2;
  end process;

  -----------------------------------------------------------------
  -- Proceso de est¨ªmulos
  -----------------------------------------------------------------
  stim_proc: process
    variable rx_byte : std_logic_vector(7 downto 0);
  begin
    report "--- INICIANDO TEST DEL SISTEMA lab5fifo ---";
    
    -- Reset inicial
    rst <= '1';
    wait for 100 ns;
    rst <= '0';
    wait for 200 ns;

    -- Enviar 3 bytes consecutivos por RxD
    report "FASE 1: Enviando 0x41 ('A')";
    send_rs232_byte(x"41", RxD);
    wait for baud_period * 20;   -- tiempo de guarda
    
   

    report "FASE 2: Enviando 0x5A ('Z')";
    send_rs232_byte(x"5A", RxD);
    wait for baud_period * 20;
       report "Recibiendo segundo byte (esperado 0x5A)";
 

    report "FASE 3: Enviando 0x03 (ETX)";
    send_rs232_byte(x"03", RxD);
    wait for baud_period * 20;

      report "Recibiendo tercer byte (esperado 0x03)";
   

    wait for baud_period * 3;   -- esperar a que el transmisor empiece

    report "-------------------------------------------------------";
    report "--- TEST FINALIZADO CON ?XITO ---";
    report "-------------------------------------------------------";

    wait;  -- detener la simulaci¨®n
  end process;

end bench;