library ieee;
use ieee.std_logic_1164.all;

entity rs232transmitter is
  generic (
    FREQ_KHZ : natural ;  -- frecuencia del sistema en KHz (50 MHz)
    BAUDRATE : natural ;     -- velocidad de comunicación en baudios
  );
  port (
    clk      : in  std_logic;                     -- reloj del sistema
    rst      : in  std_logic;                     -- reset síncrono
    dataRdy  : in  std_logic;                     -- petición de envío (1 ciclo)
    data     : in  std_logic_vector(7 downto 0);  -- dato a transmitir
    busy     : out std_logic;                     -- transmisión en curso
    TxD      : out std_logic                      -- salida serie RS-232
  );
end rs232transmitter;

architecture Structural of rs232transmitter is
  
  -- Señales de control entre controller y datapath
  signal datapath_ctrl : std_logic_vector(3 downto 0);
  
  -- Señales internas del datapath
  signal writeTxD  : std_logic;
  signal bitPosCntTC: std_logic;
  
  -- Componentes
  component rs232transController
    port (
      clk          : in  std_logic;
      rst          : in  std_logic;
      dataRdy      : in  std_logic;
      writeTxD     : in  std_logic;
      bitPosCntTC  : in  std_logic;
      datapath     : out std_logic_vector(3 downto 0)
    );
  end component;
  
  component rs232transDatapath
    generic (
      FREQ_KHZ : natural;
      BAUDRATE : natural
    );
    port (
      clk          : in  std_logic;
      rst          : in  std_logic;
      datapath     : in  std_logic_vector(3 downto 0);
      data         : in  std_logic_vector(7 downto 0);
      writeTxD     : out std_logic;
      bitPosCntTC  : out std_logic;
      TxD          : out std_logic;
      busy         : out std_logic
    );
  end component;
  
begin

  -- Instanciación del Controller
  controller : rs232transController
    port map (
      clk          => clk,
      rst          => rst,
      dataRdy      => dataRdy,
      writeTxD     => writeTxD,
      bitPosCntTC  => bitPosCntTC,
      datapath     => datapath_ctrl,
      busy         => busy
    );

  -- Instanciación del Datapath
  datapath : rs232transDatapath
    generic map (
      FREQ_KHZ => FREQ_KHZ,
      BAUDRATE => BAUDRATE
    )
    port map (
      clk          => clk,
      rst          => rst,
      datapath     => datapath_ctrl,
      data         => data,
      writeTxD     => writeTxD,
      bitPosCntTC  => bitPosCntTC,
      TxD          => TxD
    );

end Structural;