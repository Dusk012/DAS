-------------------------------------------------------------------
--
--  Fichero:
--    rs232receiver.vhd  12/09/2023
--
--    (c) J.M. Mendias
--    Dise帽o Autom谩tico de Sistemas
--    Facultad de Inform谩tica. Universidad Complutense de Madrid
--
--  Prop贸sito:
--    Conversor elemental de una linea serie RS-232 a paralelo con
--    protocolo de strobe
--
--  Notas de dise帽o:
--    - Parity: NONE
--    - Num data bits: 8
--    - Num stop bits: 1
--
-------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity rs232receiver is
  generic (
    FREQ_KHZ : natural;  -- frecuencia de operacion en KHz
    BAUDRATE : natural   -- velocidad de comunicacion
  );
  port (
    -- host side
    clk     : in  std_logic;   -- reloj del sistema
    rst     : in  std_logic;   -- reset s铆ncrono del sistema
    dataRdy : out std_logic;   -- se activa durante 1 ciclo cada vez que hay un nuevo dato recibido
    data    : out std_logic_vector (7 downto 0);   -- dato recibido
    -- RS232 side
    RxD     : in  std_logic    -- entrada de datos serie del interfaz RS-232
  );
end rs232receiver;

-------------------------------------------------------------------

use work.common.all;

architecture syn of rs232receiver is

  signal RxDSync     : std_logic;
  signal readRxD     : std_logic;
  signal bitPosCntTC : std_logic;
  signal ctrl        : std_logic_vector(2 downto 0); -- (baudCntCE, bitPosCntCE, RxDShfSH) aunque este 煤ltimo no se usa

begin

  -- Sincronizador de la entrada as铆ncrona RxD
  RxDSynchronizer : synchronizer
    generic map ( STAGES => 2, XPOL => '1' )
    port map ( clk => clk, x => RxD, xSync => RxDSync );

  -- Controlador
  controller: entity work.rs232recController
    port map (
      clk          => clk,
      rst          => rst,
      RxDSync      => RxDSync,
      readRxD      => readRxD,
      bitPosCntTC  => bitPosCntTC,
      dataRdy      => dataRdy,
      datapath     => ctrl
    );

  -- Ruta de datos
  datapath: entity work.rs232recDatapath
    generic map (
      FREQ_KHZ => FREQ_KHZ,
      BAUDRATE => BAUDRATE
    )
    port map (
      clk          => clk,
      rst          => rst,
      RxDSync      => RxDSync,
      datapath     => ctrl,
      readRxD      => readRxD,
      bitPosCntTC  => bitPosCntTC,
      data         => data
    );

end syn;