---------------------------------------------------------------------
--
--  Fichero:
--    modcounter.vhd  07/09/2023
--
--    (c) J.M. Mendias
--    Dise�o Autom�tico de Sistemas
--    Facultad de Inform�tica. Universidad Complutense de Madrid
--
--  Prop�sito:
--    Contador ascendente gen�rico (en n�m. de bits y valor m�ximo)
--
--  Notas de dise�o:
--    Orientado a FPGA Xilinx 7 series: reset sincrono y valor inicial
--
---------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use work.common.all;

entity modCounter is
  generic
  (
    MAXVAL : natural   -- valor maximo alcanzable
  );
  port
  (
    clk   : in  std_logic;   -- reloj del sistema
    rst   : in  std_logic;   -- reset (puesta a 0) sincrono
    ce    : in  std_logic;   -- capacitacion de cuenta
    tc    : out std_logic;   -- fin de cuenta
    count : out std_logic_vector(log2(MAXVAL)-1 downto 0)   -- cuenta
  );
end modCounter;

---------------------------------------------------------------------

library ieee;
use ieee.numeric_std.all;

architecture syn of modCounter is

  signal cs : unsigned(count'range) := (others => '0');
  
begin

  stateReg:
  process (clk)
  begin
    if rising_edge(clk) then
      if rst='1' then    
        cs <= (others => '0');  
      elsif ce = '1' then  
        if cs = to_unsigned(MAXVAL, cs'length) then
          cs <= (others => '0');  
        else 
          cs <= cs + 1;
        end if;
      end if;
    end if;
  end process;

  count <= std_logic_vector(cs);
  
  tc <= '1' when cs = to_unsigned(MAXVAL, cs'length) else '0';

end syn;
