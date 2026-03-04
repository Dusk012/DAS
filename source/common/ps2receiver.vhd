-------------------------------------------------------------------
--
--  Fichero:
--    ps2receiver.vhd  12/09/2023
--
--    (c) J.M. Mendias
--    Diseño Automático de Sistemas
--    Facultad de Informática. Universidad Complutense de Madrid
--
--  Propósito:
--    Conversor elemental de una linea serie PS2 a paralelo con 
--    protocolo de strobe de 1 ciclo
--
--  Notas de diseño:
--
-------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity ps2receiver is
  port (
    -- host side
    clk        : in  std_logic;   -- reloj del sistema
    rst        : in  std_logic;   -- reset síncrono del sistema      
    dataRdy    : out std_logic;   -- se activa durante 1 ciclo cada vez que hay un nuevo dato recibido
    data       : out std_logic_vector (7 downto 0);  -- dato recibido
    -- PS2 side
    ps2Clk     : in  std_logic;   -- entrada de reloj del interfaz PS2
    ps2Data    : in  std_logic    -- entrada de datos serie del interfaz PS2
  );
end ps2receiver;

-------------------------------------------------------------------

use work.common.all;

architecture syn of ps2receiver is
 
  signal ps2DataShf: std_logic_vector(10 downto 0) := (others =>'1');

  signal ps2ClkSync, ps2DataSync, ps2ClkFall: std_logic;
  signal lastBit, parityOK: std_logic;

begin

  ps2ClkSynchronizer : synchronizer
    ...

  ps2DataSynchronizer : synchronizer
    ...

  ps2ClkEdgeDetector : edgeDetector
    ...

  ps2DataShifter:
  process (clk)
  begin
    if rising_edge(clk) then
      ...
    end if;
  end process;

  oddParityCheker :
  process(ps2DataShf)
    variable aux : std_logic;
  begin
    aux := ...;
    for i in ... loop
      ...;
    end loop;
    parityOK <= aux;
  end process;

  lastBitCheker :
  lastBit <= ...;  
   
  outputRegisters :
  process (clk)
  begin
    if rising_edge(clk) then
      ...
    end if;
  end process;
    
end syn;
