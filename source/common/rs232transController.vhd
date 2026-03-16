library ieee;
use ieee.std_logic_1164.all;

entity rs232transController is
  port (
    clk          : in  std_logic;                    -- reloj del sistema
    rst          : in  std_logic;                    -- reset síncrono
    dataRdy      : in  std_logic;                    -- petición de envío
    writeTxD         : in  std_logic;                    -- pulso de bit (desde el contador de baudios)
    bitPosCntTC  : in  std_logic;                    -- fin de cuenta del contador de bits (bit 9)
    datapath     : out std_logic_vector(3 downto 0);  -- señales de control
    busy         : out  std_logic 
  );
end rs232transController;

architecture Behavioral of rs232transController is
  type state_t is (IDLE, TRANSMIT);
  signal state, next_state : state_t;

  signal ctrl: std_logic_vector(3 downto 0);
  alias TxDShfLD  : std_logic is ctrl(0);   -- carga del registro de desplazamiento
  alias TxDShfSH  : std_logic is ctrl(1);   -- desplazamiento del registro
  alias baudCntCE : std_logic is ctrl(2);   -- habilita el contador de baudios
  alias bitPosCntCE : std_logic is ctrl(3); -- habilita el contador de bits
begin

  datapath <= ctrl;  -- Asignación de las señales de control a la salida


  -- Registro de estado
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

  -- Lógica combinacional de siguiente estado y salidas
  comb_process : process(state, dataRdy, writeTxD, bitPosCntTC)
  begin
    -- Valores por defecto
    TxDShfLD  <= '0';
    TxDShfSH  <= '0';
    baudCntCE <= '0';
    busy      <= '0';
    bitPosCntCE <= '0';
    next_state <= state;

    case state is
      when IDLE =>
        if dataRdy = '1' then
          TxDShfLD   <= '1';          -- carga el dato en el registro
          bitPosCntCE <= '1';
          next_state <= TRANSMIT;
        end if;

      when TRANSMIT =>
        busy      <= '1';
        baudCntCE <= '1';              -- activa el contador de baudios
        if writeTxD = '1' then
          bitPosCntCE <= '1';             -- mantiene habilitado el contador de bits
          TxDShfSH <= '1';              -- desplaza en cada writeTxD
          if bitPosCntTC = '1' then     -- si es el último bit, termina
            next_state <= IDLE;
          end if;
        end if;
    end case;
  end process;

end Behavioral;