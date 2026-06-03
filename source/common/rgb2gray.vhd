---------------------------------------------------------------------
--
--  Fichero:
--    rgb2grey.vhd  27/02/2024
--
--    (c) J.M. Mendias
--    Dise�o Autom�tico de Sistemas
--    Facultad de Inform�tica. Universidad Complutense de Madrid
--
--  Prop�sito:
--    Convierte un color RGB a escala de grises
--
--  Notas de dise�o:
--    - Para pantallas con 4b por canal
--
---------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity rgb2grey is
  port (
    -- camera side
    rgb  : in std_logic_vector(11 downto 0);   -- color
    -- screen side
    grey : out std_logic_vector(3 downto 0)    -- gris
  );
end rgb2grey;

-------------------------------------------------------------------

library ieee;
use ieee.numeric_std.all;

architecture syn of rgb2grey is
  
  function touFix( d: real; qn : natural; qm : natural ) return unsigned is 
  begin 
    return to_unsigned( natural(d*(2.0**qm)), qn+qm );
  end function; 
  
  constant Rcoef : unsigned(7 downto 0) := touFix( 0.299, 0, 8 );
  constant Gcoef : unsigned(7 downto 0) := touFix( 0.587, 0, 8 );
  constant Bcoef : unsigned(7 downto 0) := touFix( 0.114, 0, 8 );
  
  signal acc     : unsigned(11 downto 0);
  signal R, G, B : unsigned(3 downto 0);

begin 

  R <= unsigned(rgb(11 downto 8));
  G <= unsigned(rgb(7 downto 4));
  B <= unsigned(rgb(3 downto 0));

  acc <= (R * Rcoef) + (G * Gcoef) + (B * Bcoef);

  grey <= std_logic_vector(acc(11 downto 8));
    
end syn;