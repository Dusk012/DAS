library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all; -- Añadido para permitir operaciones aritméticas con std_logic_vector
use work.common.all;

architecture syn of vgaRefresher is

  constant CYCLESxPIXEL : natural := FREQ_DIV;
  constant PIXELSxLINE  : natural := 800;
  constant LINESxFRAME  : natural := 525;
     
  signal hSyncInt, vSyncInt : std_logic;

  -- Se cambian los contadores de natural/unsigned a std_logic_vector
  -- A cycleCnt se le da un tamaño genérico de 32 bits para asegurar que cubra cualquier FREQ_DIV
  signal cycleCnt : std_logic_vector(31 downto 0) := (others=>'0');  
  signal pixelCnt : std_logic_vector(9 downto 0)  := (others=>'0');
  signal lineCnt  : std_logic_vector(9 downto 0)  := (others=>'0');

  -- Se cambia boolean por std_logic
  signal blanking : std_logic;
  
begin

  counters:
  process (clk)
  begin
    if rising_edge(clk) then
      cycleCnt <= cycleCnt + 1;
      if cycleCnt = CYCLESxPIXEL-1 then
        cycleCnt <= (others=>'0');
        pixelCnt <= pixelCnt + 1;
        if pixelCnt = PIXELSxLINE-1 then
          pixelCnt <= (others=>'0');
          lineCnt <= lineCnt + 1;
          if lineCnt = LINESxFRAME-1 then
            lineCnt <= (others=>'0');
          end if;
        end if;
      end if;
    end if;
  end process;

  -- Al ser ya std_logic_vector, la asignación es directa (sin conversiones)
  pixel <= pixelCnt;
  line  <= lineCnt;
  
  hSyncInt <= '0' when (pixelCnt >= 656 and pixelCnt < 752) else '1';
  vSyncInt <= '0' when (lineCnt >= 490 and lineCnt < 492) else '1';        

  -- blanking ahora toma valores '1' o '0' en lugar de true o false
  blanking <= '1' when (pixelCnt >= 640) or (lineCnt >= 480) else '0';
  
  outputRegisters:
  process (clk)
  begin
    if rising_edge(clk) then
      hSync <= hSyncInt;
      vSync <= vSyncInt;
      
      -- Se evalúa si blanking está a '1'
      if blanking = '1' then
        RGB <= (others => '0');
      else
        RGB <= R & G & B;
      end if;
    end if;
  end process;
    
end syn;