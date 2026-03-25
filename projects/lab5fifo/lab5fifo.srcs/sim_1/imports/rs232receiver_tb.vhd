library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity rs232receiver_tb is
end rs232receiver_tb;

architecture bench of rs232receiver_tb is

  -- Declaración del componente principal [cite: 169-171]
  component rs232receiver
    generic (
      FREQ_KHZ : natural;
      BAUDRATE : natural
    );
    port (
      clk     : in  std_logic;
      rst     : in  std_logic;
      dataRdy : out std_logic;
      data    : out std_logic_vector (7 downto 0);
      RxD     : in  std_logic
    );
  end component;

  -- Configuración de la Basys 3 y RS-232 [cite: 121, 169]
  constant FREQ_KHZ : natural := 100000; -- 100 MHz
  constant BAUDRATE : natural := 9600;   
  
  -- Señales de interconexión [cite: 49-53]
  signal clk     : std_logic := '0';
  signal rst     : std_logic := '0';
  signal dataRdy : std_logic;
  signal data    : std_logic_vector(7 downto 0);
  signal RxD     : std_logic := '1'; -- Línea en reposo (High)

  -- Tiempos calculados [cite: 54]
  constant clk_period  : time := 10 ns;
  constant baud_period : time := 104166 ns; -- 1/9600 s

  -- PROCEDIMIENTO CORREGIDO: Envía la trama sin bloquear el bit de Stop
  procedure send_rs232_byte (
    constant byte_val : in std_logic_vector(7 downto 0);
    signal rx_line    : out std_logic
  ) is
  begin
    report "   [TX] Enviando bit de START (0)...";
    rx_line <= '0';
    wait for baud_period;
    
    for i in 0 to 7 loop
      report "   [TX] Enviando bit de datos " & integer'image(i) & ": " & std_logic'image(byte_val(i));
      rx_line <= byte_val(i);
      wait for baud_period;
    end loop;
    
    report "   [TX] Iniciando bit de STOP (1) y habilitando escucha...";
    rx_line <= '1';
    -- NOTA: No esperamos el baud_period aquí para que el proceso principal 
    -- pueda capturar el dataRdy que ocurre a mitad de este bit.
  end procedure;

begin

  -- Instancia del Unit Under Test (UUT) [cite: 55, 178-179]
  uut: rs232receiver
    generic map (
      FREQ_KHZ => FREQ_KHZ,
      BAUDRATE => BAUDRATE
    )
    port map (
      clk     => clk,
      rst     => rst,
      dataRdy => dataRdy,
      data    => data,
      RxD     => RxD
    );

  -- Generador de reloj de 100 MHz [cite: 57-58]
  clk_process : process
  begin
    clk <= '0'; wait for clk_period/2;
    clk <= '1'; wait for clk_period/2;
  end process;

  -- Proceso de estímulos verboso [cite: 59-75]
  stim_proc: process
  begin		
    report "--- INICIANDO TEST DEL RECEPTOR RS-232 ---";
    -- Fase 1: Reset [cite: 59]
    rst <= '1';
    wait for 100 ns;
    rst <= '0';
    wait for 200 ns;

    -- Fase 2: Envío de 0x41 ('A') [cite: 60-63]
    report "FASE 1: Enviando byte 0x41 ('A')...";
    send_rs232_byte(x"41", RxD);
    
    -- Ahora el proceso sí llegará a tiempo para ver el pulso [cite: 163]
    wait until dataRdy = '1'; 
    --report ">>> RECEPCION DETECTADA. Dato capturado: " & to_hstring(data);
    
    assert data = x"41" report "ERROR: El dato recibido no es 0x41" severity failure;
    report "FASE 1 OK.";
    wait for baud_period; -- Terminamos de consumir el tiempo del bit de stop

    -- Fase 3: Envío de 0x5A ('Z')
    report "FASE 2: Enviando byte 0x5A ('Z')...";
    send_rs232_byte(x"5A", RxD);
    
    wait until dataRdy = '1';
    --report ">>> RECEPCION DETECTADA. Dato capturado: " & to_hstring(data);
    
    assert data = x"5A" report "ERROR: El dato recibido no es 0x5A" severity failure;
    report "FASE 2 OK.";

    report "-------------------------------------------------------";
    report "--- TEST FINALIZADO CON EXITO ---";
    report "-------------------------------------------------------";
    wait;
  end process;

end architecture;