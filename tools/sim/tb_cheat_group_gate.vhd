library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

entity tb_cheat_group_gate is end;
architecture test of tb_cheat_group_gate is
 signal clk : std_logic := '0';
 signal gb_on : std_logic := '0';
 signal cheat_on : std_logic := '0';
 signal cheat_in : std_logic_vector(127 downto 0) := (others => '0');
 signal vsync : std_logic := '0';
 signal bus_ena : std_logic;
 signal bus_rnw : std_logic;
 signal bus_addr : std_logic_vector(27 downto 0);
 signal bus_acc : std_logic_vector(1 downto 0);
 signal bus_wdata : std_logic_vector(31 downto 0);
 signal bus_done : std_logic := '0';
 signal bus_read : std_logic_vector(31 downto 0) := (others => '0');
 signal active : std_logic;
 signal sleep : std_logic;
 signal reads : natural := 0;
 signal last_write_addr : std_logic_vector(27 downto 0) := (others => '0');
 signal writes : natural := 0;
begin
 clk <= not clk after 5 ns;
 dut : entity work.gba_cheats
 port map(clk100=>clk,gb_on=>gb_on,cheat_clear=>'0',
 cheats_enabled=>'1',group_mode=>'1',group_mask=>x"00000002",
 cheat_on=>cheat_on,cheat_in=>cheat_in,cheats_active=>active,
 vsync=>vsync,bus_ena_in=>'0',sleep_cheats=>sleep,
 BusAddr=>bus_addr,BusRnW=>bus_rnw,BusACC=>bus_acc,
 BusWriteData=>bus_wdata,Bus_ena=>bus_ena,BusReadData=>bus_read,
 BusDone=>bus_done);
 process(clk)
 begin
  if rising_edge(clk) then
   bus_done <= bus_ena;
   if bus_ena='1' then
    if bus_rnw='1' then reads<=reads+1;
    else writes<=writes+1; last_write_addr<=bus_addr;
    end if;
   end if;
  end if;
 end process;
 process
  procedure push(constant gid : natural; constant addr : natural; constant op : natural := 0) is
   variable w : std_logic_vector(127 downto 0);
  begin
   w := (others=>'0');
   w(111 downto 104) := std_logic_vector(to_unsigned(gid,8));
   w(103 downto 100) := "1111";
   w(99 downto 96) := std_logic_vector(to_unsigned(op,4));
   w(91 downto 64) := std_logic_vector(to_unsigned(addr,28));
   w(31 downto 0) := x"12345678";
   cheat_in <= w;
   wait until falling_edge(clk);
   cheat_on <= '1';
   wait until falling_edge(clk);
   cheat_on <= '0';
   wait for 350 ns;
  end procedure;
 begin
  wait for 350 ns;
  gb_on <= '1';
  wait for 50 ns;
  push(0,16#2000000#);
  push(1,16#2000004#);
  wait for 300 ns;
  vsync <= '1';
  wait until falling_edge(clk);
  vsync <= '0';
  wait for 4000 ns;
  assert reads=1 report "disabled group caused read or enabled group missing read" severity failure;
  assert writes=1 report "disabled group caused write or enabled group missing write" severity failure;
  report "PASS group mask: group 0 disabled, group 1 enabled" severity note;
  gb_on <= '0';
  wait for 350 ns;
  gb_on <= '1';
  wait for 50 ns;
  push(0,16#2000000#,1);
  push(1,16#2000008#);
  wait for 300 ns;
  vsync <= '1';
  wait until falling_edge(clk);
  vsync <= '0';
  wait for 4000 ns;
  assert reads=2 report "boundary: expected one additional read" severity failure;
  assert writes=2 report "boundary: expected one additional write" severity failure;
  assert last_write_addr=std_logic_vector(to_unsigned(16#2000008#,28))
    report "boundary: wrong write address" severity failure;
  report "PASS disabled conditional cannot suppress next enabled group" severity note;
  stop;
  wait;
 end process;
end architecture;
