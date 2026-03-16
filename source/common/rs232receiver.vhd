-------------------------------------------------------------------
--
--  Fichero:
--    rs232receiver.vhd  12/09/2023
--
--    (c) J.M. Mendias
--    Dise�o Autom�tico de Sistemas
--    Facultad de Inform�tica. Universidad Complutense de Madrid
--
--  Prop�sito:
--    Conversor elemental de una linea serie RS-232 a paralelo con 
--    protocolo de strobe
--
--  Notas de dise�o:
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
    rst     : in  std_logic;   -- reset s�ncrono del sistema
    dataRdy : out std_logic;   -- se activa durante 1 ciclo cada vez que hay un nuevo dato recibido
    data    : out std_logic_vector (7 downto 0);   -- dato recibido
    -- RS232 side
    RxD     : in  std_logic    -- entrada de datos serie del interfaz RS-232
  );
end rs232receiver;

-------------------------------------------------------------------

use work.common.all;

architecture syn of rs232receiver is

  constant CYCLES_PER_BIT : natural := (FREQ_KHZ * 1000) / BAUDRATE;
  constant HALF_CYCLE      : natural := CYCLES_PER_BIT / 2;
  constant BAUD_CNT_WIDTH  : natural := log2(CYCLES_PER_BIT);  -- ancho necesario para el contador

  signal RxDSync : std_logic;
  signal readRxD, baudCntCE : std_logic;

  signal baud_count : std_logic_vector(BAUD_CNT_WIDTH-1 downto 0);


  type states is (S0, REEIVING);
  signal state, next_state : states;

begin

  RxDSynchronizer : synchronizer
    generic map ( STAGES => 2, XPOL => '1' )
    port map ( clk => clk, x => RxD, xSync => RxDSync );

  baudCnt:
  process (clk)
  begin
    readRxD <= ( count = CYCLES/2-1 );
    if rising_edge(clk) then
      if rst = 1 then

      ...
    end if;
  end process;
  
  fsmd:
  process (clk)
    ...
  begin
    data      <= ...;
    baudCntCE <= ...;
    if rising_edge(clk) then
      if rst='1' then
        ...
      else
        case bitPos is
          when 0 =>                              -- Esperando bit de start
            dataRdy   <= '0';      
            ...
          when others =>                         -- Desplaza
            if readRxD then 
              if bitPos = 10 then
                dataRdy <= '1';
              end if;
              ...
            end if;
        end case;
      end if;
    end if;
  end process;
  
end syn;
