---------------------------------------------------------------------
--
--  Fichero:
--    lab5.vhd  12/09/2023
--
--    (c) J.M. Mendias
--    Diseño Automático de Sistemas
--    Facultad de Informática. Universidad Complutense de Madrid
--
--  Propósito:
--    Laboratorio 5: Loopback con FIFO
--
--  Notas de diseño:
--    - Se evita el uso de variables en la lógica de los LEDs.
--
---------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.common.all;

entity lab5 is
  port (
    clk    : in  std_logic;
    rst    : in  std_logic;
    RxD    : in  std_logic;
    TxD    : out std_logic;
    TxEn   : in  std_logic;
    leds   : out std_logic_vector(15 downto 0);
    an_n   : out std_logic_vector(3 downto 0);
    segs_n : out std_logic_vector(7 downto 0)
  );
end lab5;

architecture syn of lab5 is

  constant FREQ_KHZ : natural := 100_000;
  constant BAUDRATE : natural := 1200;

  signal dataRx, dataTx      : std_logic_vector(7 downto 0):= (others => '0');
  signal dataRdyTx, dataRdyRx : std_logic;
  signal busy, empty, full    : std_logic;

  signal rstSync, TxEnSync    : std_logic;
  signal fifoStatus           : std_logic_vector(3 downto 0);
  signal numData              : std_logic_vector(3 downto 0);
  signal en                   : std_logic;
  
  attribute mark_debug : string;
  attribute mark_debug of dataRx  : signal is "true";
  attribute mark_debug of dataTx : signal is "true";
  attribute mark_debug of dataRdyTx : signal is "true";
  attribute mark_debug of dataRdyRx    : signal is "true";
   attribute mark_debug of busy    : signal is "true";
  
  component fifo_generator_0 IS
  PORT (
    clk : IN STD_LOGIC;
    srst : IN STD_LOGIC;
    din : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    wr_en : IN STD_LOGIC;
    rd_en : IN STD_LOGIC;
    dout : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    full : OUT STD_LOGIC;
    empty : OUT STD_LOGIC;
    data_count : OUT STD_LOGIC_VECTOR(3 DOWNTO 0)
  );
END component;

begin

  rstSynchronizer : synchronizer
    generic map ( STAGES => 2, XPOL => '0' )
    port map ( clk => clk, x => rst, xSync => rstSync );

  TxEnSynchronizer : synchronizer
    generic map ( STAGES => 2, XPOL => '0' )
    port map ( clk => clk, x => TxEn, xSync => TxEnSync );

  receiver: rs232receiver
    generic map ( FREQ_KHZ => FREQ_KHZ, BAUDRATE => BAUDRATE )
    port map (
      clk     => clk,
      rst     => rstSync,
      dataRdy => dataRdyRx,
      data    => dataRx,
      RxD     => RxD
    );

--fifo : fifo_generator_0
   -- port map(
    -- clk  => clk,
   -- srst => rstSync,
   -- din  => dataRx,
   -- wr_en  => dataRdyRx,
   -- rd_en => dataRdyTx,
   -- dout => dataTx,
   -- full  => full,
    --empty  => empty,
    --data_count => numData
   -- );
    
    fifo : fifoQueue
    generic map(
    WL   => 8,
    DEPTH => 16
  )
    port map(
       clk   => clk,
    rst     => rstSync,
    wrE      => dataRdyRx,
    dataIn   => dataRx,
    rdE     => dataRdyTx,
    dataOut  => dataTx,
    numData => numData,
    full     => full,
    empty  => empty
    );

  dataRdyTx <= TxEnSync and not busy and not empty;

  transmitter: rs232transmitter
    generic map ( FREQ_KHZ => FREQ_KHZ, BAUDRATE => BAUDRATE )
    port map (
      clk     => clk,
      rst     => rstSync,
      dataRdy => dataRdyTx,
      data    => dataTx,
      busy    => busy,
      TxD     => TxD
    );

  fifoStatus <= X"F" when full = '1' else X"E";
  en <= full or empty;

  -- Generación de los LEDs sin variables (usando generate)
  gen_leds: for i in 0 to 15 generate
    leds(i) <= '1' when (full = '1') or (to_integer(unsigned(numData)) > i) else '0';
  end generate;

  displayInterface : segsBankRefresher
    generic map ( FREQ_KHZ => FREQ_KHZ, SIZE => 4 )
    port map (
      clk   => clk,
      ens   => "110" & en,
      bins => dataRx & "0000" & fifoStatus,
      dps   => "0000",
      an_n  => an_n,
      segs_n => segs_n
    );

end syn;