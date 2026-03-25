---------------------------------------------------------------------
--
--  Fichero:
--    lab5loopback.vhd  12/09/2023
--
--    (c) J.M. Mendias
--    Diseño Automático de Sistemas
--    Facultad de Informática. Universidad Complutense de Madrid
--
--  Propósito:
--    Laboratorio 5: Loopback sin FIFO
--
--  Notas de diseño:
--
---------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity lab5loopback is
  port (
    clk :  in std_logic;
    rst :  in std_logic;
    RxD :  in std_logic; 
    TxD : out std_logic
  );
END lab5loopback;

-----------------------------------------------------------------

library ieee;
use ieee.numeric_std.all;
use work.common.all;

architecture syn of lab5loopback is

  constant FREQ_KHZ : natural := 100_000;  -- frecuencia de operacion en KHz
  constant BAUDRATE : natural := 1200;     -- velocidad de transmisión

  signal rstSync : std_logic;

  signal data    : std_logic_vector (7 downto 0);
  signal dataRdy : std_logic;
    
begin

  rstSynchronizer : synchronizer
    generic map ( STAGES => 2, XPOL => '0' )
    port map ( clk => clk, x => rst, xSync => rstSync );
    
  receiver: rs232receiver
    generic map ( FREQ_KHZ => FREQ_KHZ, BAUDRATE => BAUDRATE )
    port map ( clk => clk, rst => rstSync, dataRdy => dataRdy, data => data, RxD => RxD );
   
  transmitter: rs232transmitter 
    generic map ( FREQ_KHZ => FREQ_KHZ, BAUDRATE => BAUDRATE )
    port map ( clk => clk, rst => rstSync, dataRdy => dataRdy, data => data, busy => open, TxD => TxD );
    
end syn;