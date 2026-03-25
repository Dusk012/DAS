library ieee;
use ieee.std_logic_1164.all;

entity rs232transmitter is
  generic (
    FREQ_KHZ : natural ;  -- frecuencia del sistema en KHz (50 MHz)
    BAUDRATE : natural      -- velocidad de comunicaci贸n en baudios
  );
  port (
    clk      : in  std_logic;                     -- reloj del sistema
    rst      : in  std_logic;                     -- reset s铆ncrono
    dataRdy  : in  std_logic;                     -- petici贸n de env铆o (1 ciclo)
    data     : in  std_logic_vector(7 downto 0);  -- dato a transmitir
    busy     : out std_logic;                     -- transmisi贸n en curso
    TxD      : out std_logic                      -- salida serie RS-232
  );
end rs232transmitter;

architecture Structural of rs232transmitter is
  
  -- Se帽ales de control entre controller y datapath
  signal datapath_ctrl : std_logic_vector(3 downto 0);
  
  -- Se帽ales internas del datapath
  signal writeTxD  : std_logic;
  signal bitPosCntTC: std_logic;
  
begin

  -- Instanciaci贸n del Controller
  controller : entity work.rs232transController
    port map (
      clk          => clk,
      rst          => rst,
      dataRdy      => dataRdy,
      writeTxD     => writeTxD,
      bitPosCntTC  => bitPosCntTC,
      datapath     => datapath_ctrl,
      busy         => busy
    );

  -- Instanciaci贸n del Datapath
  datapath : entity work.rs232transDatapath
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