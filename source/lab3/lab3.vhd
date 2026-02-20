---------------------------------------------------------------------
--
--  Fichero:
--    lab3.vhd  12/09/2023
--
--    (c) J.M. Mendias
--    Diseño Automático de Sistemas
--    Facultad de Informática. Universidad Complutense de Madrid
--
--  Propósito:
--    Laboratorio 3
--
--  Notas de diseño:
--
---------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity lab3 is
port
(
  aRst   : in  std_logic;
  osc    : in  std_logic;
  coin   : in  std_logic;
  go     : in  std_logic;
  an_n   : out std_logic_vector(3 downto 0);  
  segs_n : out std_logic_vector(7 downto 0)
);
end lab3;

---------------------------------------------------------------------

library ieee;
use ieee.numeric_std.all;
use work.common.all;

architecture syn of lab3 is

  constant OSC_KHZ   : natural := 100_000;     -- frecuencia del oscilador externo en KHz
  constant FREQ_KHZ  : natural := OSC_KHZ/10;  -- frecuencia de operacion en KHz
  constant BOUNCE_MS : natural := 50;          -- tiempo de rebote de los pulsadores en ms
  
  type reelType is array (2 downto 0) of unsigned(3 downto 0);

  -- Registros  
  signal credit : unsigned(3 downto 0) := (others => '0');
  signal reel   : reelType             := (others => (others => '0'));

  -- Señales 
  signal clk, rdy : std_logic;
  signal rstSync, rstAux : std_logic;
  signal coinSync, coinDeb, coinRise : std_logic;
  signal goSync, goDeb, goRise       : std_logic;

  signal spin : std_logic_vector(2 downto 0);
  signal decCredit, incCredit, hasCredit : std_logic;
  signal cycleCntTC : std_logic;  

begin

  rstAux <= ...;
  
  resetSyncronizer : asyncRstSynchronizer
    generic map ( STAGES => 2, XPOL => '0' )
    port map ( ... );
    
  clkGenerator : freqSynthesizer
    generic map ( FREQ_KHZ => OSC_KHZ, MULTIPLY => 1, DIVIDE => 10 )
    port map ( ... );
      
  ------------------  
  
  coinSynchronizer : synchronizer
    ...
   
  coinDebouncer : debouncer
    ...
   
  coinEdgeDetector : edgeDetector
    ...
  
  ------------------  

  goSynchronizer : synchronizer
    ...
   
  goDebouncer : debouncer
    ...
   
  goEdgeDetector : edgeDetector
    ...
  
  ------------------  
 
  fsm:
  process (rstSync, clk, goRise, hasCredit)
    type states is (initial, S1, S2, S3, reward); 
    variable state: states := initial;
  begin 
    decCredit <= ...;
    incCredit <= ...;
    spin      <= ...;
    case state is
      when initial =>
        ...
    end case;
    if rstSync='1' then
      state := ...;
    elsif rising_edge(clk) then
      case state is
        when initial =>
          ...
      end case;
    end if;
  end process;  
  
  cycleCounter :  
  process (clk)
    constant CYCLES : natural := ms2cycles(FREQ_KHZ, 50);
    variable count  : natural range ... := ...;
  begin
    ...
    if rising_edge(clk) then
      ...
    end if;
  end process;
     
  reelRegisters : 
  for i in reel'range generate
  begin
    process (rstSync, clk)
    begin
      if rstSync='1' then
        reel(i) <= ...;
      elsif rising_edge(clk) then
        if spin(i)='1' then
          ...
        end if;
      end if;
    end process; 
  end generate;
 
  creditComparator: 
  hasCredit <= ...;
  
  creditRegister :
  process (rstSync, clk)
  begin
    if rstSync='1' then
      credit <= (others => '0');    
    elsif rising_edge(clk) then
      if coinRise='1' then
        ...
      elsif decCredit='1' then
        ...
      elsif incCredit='1' then
        ...
      end if;
   end if; 
  end process; 
  
  displayInterface : segsBankRefresher
    ... 

end syn;
