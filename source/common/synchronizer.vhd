-------------------------------------------------------------------
--
--  Fichero:
--    synchronizer.vhd  (modificado sin variables)
--
--    (c) J.M. Mendias
--    Diseño Automático de Sistemas
--    Facultad de Informática. Universidad Complutense de Madrid
--
--  Propósito:
--    Sincroniza una entrada binaria (versión sin variables)
--
--  Notas de diseño:
--    Orientado a FPGA Xilinx 7 series: no reset, valor inicial en señal
--
-------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity synchronizer is
  generic (
    STAGES  : natural;       -- número de biestables del sincronizador
    XPOL    : std_logic      -- polaridad (valor en reposo) de la señal a sincronizar
  );
  port (
    clk   : in  std_logic;   -- reloj del sistema
    x     : in  std_logic;   -- entrada binaria a sincronizar
    xSync : out std_logic    -- salida sincronizada que sigue a la entrada
  );
end synchronizer;

-------------------------------------------------------------------

architecture syn of synchronizer is
  signal aux : std_logic_vector(STAGES-1 downto 0) := (others => XPOL);
begin
  xSync <= aux(STAGES-1);
  process (clk)
  begin
    if rising_edge(clk) then
      aux <= aux(aux'high-1 downto 0) & x;   -- desplazamiento a la izquierda
    end if;
  end process;
end syn;