library ieee;
use ieee.std_logic_1164.all;

entity rs232recController is
  port (
    clk          : in  std_logic;                    -- reloj del sistema
    rst          : in  std_logic;                    -- reset s铆ncrono
    RxDSync      : in  std_logic;                    -- RxD sincronizado
    readRxD      : in  std_logic;                    -- pulso de muestreo (mitad de bit)
    bitPosCntTC  : in  std_logic;                    -- fin de cuenta (bit 10 alcanzado)
    dataRdy      : out std_logic;                     -- nuevo dato disponible
    datapath     : out std_logic_vector(2 downto 0)   -- control: (baudCntCE, bitPosCntCE)
  );
end rs232recController;

architecture Behavioral of rs232recController is
  type state_t is (IDLE, RECEIVE, FINAL);
  signal state, next_state : state_t;

  signal ctrl : std_logic_vector(2 downto 0);
  alias baudCntCE    : std_logic is ctrl(0);
  alias bitPosCntCE : std_logic is ctrl(1);
  alias RxDShfSH : std_logic is ctrl(2);

begin
  datapath <= ctrl;

  sync_process : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        state <= IDLE;
      else
        state <= next_state;
      end if;
    end if;
  end process;

  comb_process : process(state, RxDSync, readRxD, bitPosCntTC)
  begin
    -- Valores por defecto
    baudCntCE    <= '0';
    bitPosCntCE <= '0';
    dataRdy      <= '0';
    RxDShfSH <= '0';
    next_state   <= state;

    case state is
      when IDLE =>
        if RxDSync = '0' then               -- detecci贸n de flanco de bajada (inicio de start)
          bitPosCntCE <= '1';                -- reset del contador de bits
          next_state  <= RECEIVE;
        end if;

      when RECEIVE =>
        baudCntCE <= '1';
        if readRxD = '1' then
            RxDShfSH <= '1';
            bitPosCntCE <= '1';
          if bitPosCntTC = '1' then         -- se ha recibido el 煤ltimo bit (stop)
            next_state <= FINAL;
          end if;
        end if;
      
       when FINAL =>
            --baudCntCE <= '1';
            dataRdy   <= '1';
            next_state <= IDLE;
    end case;
  end process;
end Behavioral;