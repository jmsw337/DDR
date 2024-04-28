library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity image_generator is

	generic(
	
		Ha: integer := 96;
		Hb: integer := 144;
		Hc: integer := 784;
		Hd: integer := 800;
		Va: integer := 2;
		Vb: integer := 35;
		Vc: integer := 515;
		Vd: integer := 525;
		PVsize: integer := 50;
		PHsize: integer := 10;
		BallSize: integer := 50);
	
	port(
		clk_pix 		  : in std_logic;
		--paddle_clk		  : in std_logic;
		--ball_clk			  : in std_logic;
		reset				  : in std_logic;
		Hactive, Vactive : in std_logic;
		Hsync, Vsync     : in std_logic;
		de		 		  : in std_logic;
		--direction_switch : in std_logic_vector(3 downto 0);
		button		  : in std_logic_vector(3 downto 0) := "1111";
		m_button 		: in std_logic_vector(1 downto 0);
		start_s 		: in std_logic;
		guideline 	  : in std_logic;
		score			  : buffer integer;
		perfect			: out std_logic_vector(3 downto 0);
		great 			: out std_logic_vector(3 downto 0);
		good 			: out std_logic_vector(3 downto 0);
		miss 			: out std_logic_vector(3 downto 0);
		--score2			  : buffer integer;
		R,G,B				  : out std_logic_vector(3 downto 0);
		led : buffer std_logic_vector(9 downto 0);
		debug_pin : out std_logic);
		
end image_generator;


architecture image_generator_arch of image_generator is

	--Pixel counters

	signal sy : integer range 0 to Vc;
	signal sx : integer range 0 to Hc;

	signal y : integer;
	signal x : integer;
	
	--States of the game
	type state_type is (S0, S1);
	signal state: state_type;
	signal move: std_logic;
	
	--new signals

	signal paint_r, paint_g, paint_b : std_logic_vector(3 downto 0);

	-- Constants
	
	signal v_start : std_logic_vector(39 downto 0) := "0110000101001101001110101101010111101101";
													   
    signal h_start : std_logic_vector(29 downto 0) := "101110100100001101000011101010";
    signal stitch, v_line, v_on, h_line, h_on, last_h_stitch : std_logic;

	constant V_RES : integer := 480;
	signal frame : std_logic;
	constant FRAME_NUM1 : integer := 195; --195 good bpm
	constant FRAME_NUM2 : integer := 350; --410 too slow
	signal cnt_frame : integer := 0;

	signal spongeframe : integer range 0 to 33;
	constant SPONGE_FRAME : integer := 1250000;
	signal spongecount : integer range 0 to SPONGE_FRAME;

	--signal draw : integer range 0 to 540 := 0;
	--signal drawline : std_logic;

	signal toggle : std_logic := '0';

	--signal drawBit : std_logic_vector(6 downto 0);

	signal draw0 : integer := 0;
	signal draw1 : integer := 160;
	signal draw2 : integer := 320;
	signal draw3 : integer := 480;

	signal draw_index : integer range -3 to 1023 := 0;
	--signal pix_index : integer range -3 to 1023 := 0;

	signal clut_in : std_logic_vector(3 downto 0);
	signal clut_out : std_logic_vector(11 downto 0);
	signal sprite_out : std_logic_vector(11 downto 0);

	--signal notes : std_logic_vector(99 downto 0);
	type notes_array is array (0 to 1023) of std_logic_vector(3 downto 0);
	signal notes : notes_array;

	type notes_draw is array (0 to 1023) of std_logic_vector(47 downto 0);
	signal notedraw : notes_draw;

	signal address : std_logic_vector(11 downto 0);
	signal q : std_logic_vector(47 downto 0);

	signal logo_address : std_logic_vector(13 downto 0);
	signal logo_q : std_logic_vector(11 downto 0);

	signal rating_address : std_logic_vector(11 downto 0);
	signal rating_q : std_logic_vector(11 downto 0);

	signal sponge_address : std_logic_vector(16 downto 0);
	signal sponge_q : std_logic_vector(11 downto 0);

	signal introscreen_address : std_logic_vector(11 downto 0);
	signal introscreen_q : std_logic_vector(11 downto 0);

	signal mb_address : std_logic_vector(11 downto 0);
	signal mb_q : std_logic_vector(11 downto 0);

	signal perfect_score : unsigned(15 downto 0);
	signal great_score : unsigned(15 downto 0);
	signal good_score : unsigned(15 downto 0);
	signal miss_score : unsigned(15 downto 0);
	signal completemiss_score : unsigned(15 downto 0);
	signal score_disp : unsigned(15 downto 0);
	signal hit : std_logic_vector(3 downto 0);

	signal score0 : unsigned(15 downto 0);
	signal score1 : unsigned(15 downto 0);
	signal score2 : unsigned(15 downto 0);
	signal score3 : unsigned(15 downto 0);

	signal scoretype : std_logic_vector(15 downto 0);

	signal completemiss : std_logic_vector(3 downto 0);
	signal complete_debounce : std_logic_vector(3 downto 0);

	signal scoreDebug : unsigned(3 downto 0);
	signal scoreIndex : integer range 0 to 192;

	signal scoreColor : std_logic_vector(11 downto 0);
	signal colorToggle : std_logic_vector(2 downto 0);

	--type state_t is (START, SONG0, SONG1, SONG0_P, SONG1_P, SONG0_N, SONG1_N, DONE);
	type state_t is (START, START_W1, START_W2, S1, S1C, S1C_W1, S1C_W2, S2, S2C, S2C_W1, S2C_W2, S1P, S1P_W1, S1P_W2, S2P, S2P_W1, S2P_W2, DONE1, DONE2, DONE_W1, DONE_W2);
	signal state_r, next_state : state_t;

	signal game_rst : std_logic;
	signal game_pause : std_logic;

	signal ls_button : std_logic_vector(1 downto 0);
	signal t_button : std_logic_vector(1 downto 0);
	signal db_button :std_logic_vector(1 downto 0);
	signal dba_button : std_logic_vector(1 downto 0);
	signal dbs_button : std_logic_vector(1 downto 0);
	signal dbe_button : std_logic_vector(1 downto 0);
	signal dbf_button : std_logic_vector(1 downto 0);

	signal db_count : integer := 0;
	signal de_count : integer := 0;

	signal idle_count : integer := 0;
	signal idle : std_logic;
	signal idle_done : std_logic;
	signal whichframe : std_logic;
begin

	process(clk_pix, reset)
	begin
		if (reset = '0') then
			state_r <= START;
		elsif (rising_edge(clk_pix)) then
			state_r <= next_state;
		end if;
	end process;

	process(dbe_button, state_r, start_s, idle_done)
	begin
		led(7 downto 0) <= (others => '0');
		next_state <= state_r;
		idle <= '0';

		case state_r is
			when START => 
				led(3 downto 0) <= "0000";

				if (dbe_button(0) = '0' and start_s = '1') then
					next_state <= START_W1;
				elsif (dbe_button(1) = '0' and start_s = '1') then
					next_state <= START_W2;
				end if;

			when START_W1 =>
				led(3 downto 0) <= "1000";
				idle <= '1';
				if ((dbe_button(0) = '1') and idle_done = '1') then
					next_state <= S1;
				end if;

			when START_W2 =>
				led(3 downto 0) <= "1000";
				idle <= '1';
				if ((dbe_button(1) = '1') and idle_done = '1') then
					next_state <= S2;
				end if;

			when S1 =>
				led(6) <= '1' xor led(6);
				next_state <= S1C;
			
			when S1C =>
				led(3 downto 0) <= "0001";
				if (dbe_button(0) = '0' and start_s = '1') then
					next_state <= S1C_W1;
				elsif (dbe_button(1) = '0' and start_s = '1') then
					next_state <= S1C_W2;
				end if;

				if (draw_index = 95) then
					next_state <= DONE1;
				end if;

			when S1C_W1 => 
				led(3 downto 0) <= "1000";
				idle <= '1';
				if ((dbe_button(0) = '1') and idle_done = '1') then
					next_state <= S2;
				end if;

			when S1C_W2 => 
				led(3 downto 0) <= "1000";
				idle <= '1';
				if ((dbe_button(1) = '1') and idle_done = '1') then
					next_state <= S1P;
				end if;

			when S1P =>
				led(3 downto 0) <= "0100";
				if (dbe_button(0) = '0' and start_s = '1') then
					next_state <= S1P_W1;
				elsif (dbe_button(1) = '0' and start_s = '1') then
					next_state <= S1P_W2;
				end if;

			when S1P_W1 => 
				led(3 downto 0) <= "1000";
				idle <= '1';
				if ((dbe_button(0) = '1') and idle_done = '1') then
					next_state <= S2;
				end if;

			when S1P_W2 => 
				led(3 downto 0) <= "1000";
				idle <= '1';
				if ((dbe_button(1) = '1') and idle_done = '1') then
					next_state <= S1C;
				end if;

			when S2 =>
				led(7) <= '1' xor led(7);
				next_state <= S2C;

			when S2C =>
				led(3 downto 0) <= "0001";
				if (dbe_button(0) = '0' and start_s = '1') then
					next_state <= S2C_W1;
				elsif (dbe_button(1) = '0' and start_s = '1') then
					next_state <= S2C_W2;
				end if;

				if (draw_index = 540) then
					next_state <= DONE2;
				end if;

			when S2C_W1 => 
				led(3 downto 0) <= "1000";
				idle <= '1';
				if ((dbe_button(0) = '1') and idle_done = '1') then
					next_state <= S1;
				end if;

			when S2C_W2 => 
				led(3 downto 0) <= "1000";
				idle <= '1';
				if ((dbe_button(1) = '1') and idle_done = '1') then
					next_state <= S2P;
				end if;

			when S2P =>
				led(3 downto 0) <= "0100";
				if (dbe_button(0) = '0' and start_s = '1') then
					next_state <= S2P_W1;
				elsif (dbe_button(1) = '0' and start_s = '1') then
					next_state <= S2P_W2;
				end if;

			when S2P_W1 => 
				led(3 downto 0) <= "1000";
				idle <= '1';
				if ((dbe_button(0) = '1') and idle_done = '1') then
					next_state <= S1;
				end if;

			when S2P_W2 => 
				led(3 downto 0) <= "1000";
				idle <= '1';
				if ((dbe_button(1) = '1') and idle_done = '1') then
					next_state <= S2C;
				end if;

			when DONE1 =>
				led(3 downto 0) <= "1111";

				if (dbe_button(0) = '0' and start_s = '1') then
					next_state <= DONE_W1;
				elsif (dbe_button(1) = '0' and start_s = '1') then
					next_state <= DONE_W2;
				end if;

			when DONE2 =>
				led(3 downto 0) <= "1111";

				if (dbe_button(0) = '0' and start_s = '1') then
					next_state <= DONE_W2;
				elsif (dbe_button(1) = '0' and start_s = '1') then
					next_state <= DONE_W1;
				end if;

			when DONE_W1 => 
				led(3 downto 0) <= "1000";
				idle <= '1';
				if ((dbe_button(0) = '1') and idle_done = '1') then
					next_state <= S2;
				end if;

			when DONE_W2 => 
				led(3 downto 0) <= "1000";
				idle <= '1';
				if ((dbe_button(1) = '1') and idle_done = '1') then
					next_state <= S1;
				end if;

			when others => null;
		end case;
	end process;


	process(clk_pix) 
	begin
		if rising_edge(clk_pix) then
			dba_button <= m_button;
			dbs_button <= dba_button;
			dbf_button <= dbs_button;
		end if;
	end process; 

	dbe_button(0) <= dba_button(0) and dbs_button(0) and dbf_button(0);
	dbe_button(1) <= dba_button(1) and dbs_button(1) and dbf_button(1);

	process(clk_pix)
	begin
		if rising_edge(clk_pix) then
			if (idle = '0') then
				idle_count <= 0;
				idle_done <= '0';
			elsif (idle_count = 12500000 and idle = '1' )then
				idle_done <= '1';
			else
				idle_count <= idle_count + 1;
			end if;
		end if;
	end process;
	
	debug_pin <= dbe_button(0);

	process(clk_pix)
	begin
		if rising_edge(clk_pix) then
	

		  if (m_button(0) /= t_button(0) and
			  db_count < 25000000) then
			db_count <= db_count + 1;
	
		  elsif db_count = 25000000 then
			t_button(0) <= m_button(0);
			
		  else
			db_count <= 0;
	
		  end if;
		end if;
	end process;
	
	db_button(0) <= t_button(0);

	led(9) <= dbe_button(0);
	led(8) <= dbe_button(1);

	process (notes)
	begin
		notes <= (others => (others => '0'));
		for i in 10 to 88 loop
			notes(i) <= "1000";

			if (i mod 16 = 0) then
				notes(i) <= "0000";
			elsif (i mod 16 = 1) then
				notes(i) <= "0010";
			elsif (i mod 16 = 2) then
				notes(i) <= "0000";
			elsif (i mod 16 = 3) then
				notes(i) <= "0001";
			elsif (i mod 16 = 4) then
				notes(i) <= "0000";
			elsif (i mod 16 = 5) then
				notes(i) <= "0100";
			elsif (i mod 16 = 6) then
				notes(i) <= "0000";
			elsif (i mod 16 = 7) then
				notes(i) <= "1000";
			elsif (i mod 16 = 8) then
				notes(i) <= "0000";
			elsif (i mod 16 = 9) then
				notes(i) <= "0010";
			elsif (i mod 16 = 10) then
				notes(i) <= "0000";
			elsif (i mod 16 = 11) then
				notes(i) <= "0001";
			elsif (i mod 16 = 12) then
				notes(i) <= "0000";
			elsif (i mod 16 = 13) then
				notes(i) <= "1000";
			elsif (i mod 16 = 14) then
				notes(i) <= "0000";
			elsif (i mod 16 = 15) then
				notes(i) <= "0010";
			else
				notes(i) <= "0000";
			end if;
		end loop;

		for i in 504 to 536 loop
			if (i mod 24 = 0) then
				notes(i) <= "0001";
			elsif (i mod 24 = 1) then
				notes(i) <= "0010";
			elsif (i mod 24 = 2) then
				notes(i) <= "0100";
			elsif (i mod 24 = 3) then
				notes(i) <= "0010";
			elsif (i mod 24 = 4) then
				notes(i) <= "0001";
			elsif (i mod 24 = 5) then
				notes(i) <= "0001";
			elsif (i mod 24 = 6) then
				notes(i) <= "0001";
			elsif (i mod 24 = 7) then
				notes(i) <= "0010";
			elsif (i mod 24 = 8) then
				notes(i) <= "0010";
			elsif (i mod 24 = 9) then
				notes(i) <= "0010";
			elsif (i mod 24 = 10) then
				notes(i) <= "0001";
			elsif (i mod 24 = 11) then
				notes(i) <= "0001";
			elsif (i mod 24 = 12) then
				notes(i) <= "0001";
			elsif (i mod 24 = 13) then
				notes(i) <= "0010";
			elsif (i mod 24 = 14) then
				notes(i) <= "0100";
			elsif (i mod 24 = 15) then
				notes(i) <= "0010";
			elsif (i mod 24 = 16) then
				notes(i) <= "0001";
			elsif (i mod 24 = 17) then
				notes(i) <= "0001";
			elsif (i mod 24 = 18) then
				notes(i) <= "0010";
			elsif (i mod 24 = 19) then
				notes(i) <= "0010";
			elsif (i mod 24 = 20) then
				notes(i) <= "0001";
			elsif (i mod 24 = 21) then
				notes(i) <= "0010";
			elsif (i mod 24 = 22) then
				notes(i) <= "0100";
			elsif (i mod 24 = 23) then
				notes(i) <= "0000";
			else
				notes(i) <= "0000";
			end if;
		end loop;

		
	end process;

	clut : entity work.clut
		port map(
			bitin => clut_in,
			bitout => clut_out);
	
	U_VGA_ROM : entity work.arrow64
    	port map(
			address	        => address,
			clock		    => clk_pix,
			q		        => q
	);

	U_LOGO_ROM : entity work.logorom
		port map(
			address	        => logo_address,
			clock		    => clk_pix,
			q		        => logo_q
	);

	U_RATING_ROM : entity work.ratingrom
		port map(
			address	        => rating_address,
			clock		    => clk_pix,
			q		        => rating_q
	);

	U_SPONGE_ROM : entity work.spongerom
		port map(
			address	        => sponge_address,
			clock		    => clk_pix,
			q		        => sponge_q
	);

	U_INTROSCREEN_ROM : entity work.introscreen
		port map(
			address	        => introscreen_address,
			clock		    => clk_pix,
			q		        => introscreen_q
	);

	U_MB_ROM : entity work.mb
		port map(
			address	        => mb_address,
			clock		    => clk_pix,
			q		        => mb_q
	);

	--Pixel counters to represent the image-----------
	
	process(clk_pix, Hactive, Vactive, Hsync, Vsync, reset)
	begin	
		if(reset = '0') then		
			sy <= 0;			
		elsif(Vsync = '0') then		
			sy <= 0;			
		elsif(Hsync'event and Hsync = '1') then					
			if(Vactive = '1') then			
				sy <= sy + 1;				
			end if;			
		end if;		
		if(reset = '0') then			
			sx <= 0;			
		elsif(Hsync = '0') then			
			sx <= 0;			
		elsif(clk_pix'event and clk_pix = '1') then		
			if(Hactive = '1') then				
				sx <= sx + 1;				
			end if;			
		end if;		
	end process;

	---Image generator--------------------
	
	process(sx, sy) 
	begin
		if (sy = V_RES and sx = 0) then
			frame <= '1';
		else
			frame <= '0';
		end if;
	end process;



	process(clk_pix, reset)
	begin 
		if (reset = '0') then
			draw_index <= 0;
			whichframe <= '0';
			cnt_frame <= 0;
		elsif rising_edge(clk_pix) then
			if state_r = S1 then
				draw_index <= 0;
				whichframe <= '0';
				cnt_frame <= 0;
			elsif state_r = S2 then
				draw_index <= 494;
				whichframe <= '1';
				cnt_frame <= 0;
			end if;

			if frame = '1' then
                if (cnt_frame = FRAME_NUM1-1 and whichframe = '0') then
                    cnt_frame <= 0;
					--if(toggle = '0') then
					if (draw0 = 160) then
						draw0 <= 0;
						draw1 <= 160;
						draw2 <= 320;
						draw3 <= 480;
						draw_index <= draw_index + 1;
						if (draw_index = 105) then
							draw_index <= 103;
						end if;
					else
						draw0 <= draw0 + 1;
						draw1 <= draw1 + 1;
						draw2 <= draw2 + 1;
						draw3 <= draw3 + 1;
					end if;

				elsif (cnt_frame = FRAME_NUM2-1 and whichframe = '1') then
					cnt_frame <= 0;
					--if(toggle = '0') then
					if (draw0 = 160) then
						draw0 <= 0;
						draw1 <= 160;
						draw2 <= 320;
						draw3 <= 480;
						draw_index <= draw_index + 1;
						if (draw_index = 605) then
							draw_index <= 603;
						end if;
					else
						draw0 <= draw0 + 1;
						draw1 <= draw1 + 1;
						draw2 <= draw2 + 1;
						draw3 <= draw3 + 1;
					end if;

                else
					if (state_r = S1P or state_r = S2P or state_r = S1C_W2 
					or state_r = S2C_W2  or state_r = START or state_r = START_W1 
					or state_r = START_W2 or state_r = DONE1 or state_r = DONE2 or state_r = DONE_W1 or state_r = DONE_W2) then
						cnt_frame <= 0;
					else
                    	cnt_frame <= cnt_frame + 1;
					end if;
					
                end if;
            end if;
		end if;
	end process;
	

	process(clk_pix, reset)
    begin
		if (reset = '0') then
			--draw_index <= 0;
			spongeframe <= 0;
			toggle <= '0';
			colorToggle <= "000";
			scoreColor <= (others => '0');
        elsif rising_edge(clk_pix) then
            

			if(spongecount = SPONGE_FRAME-1) then
				spongecount <= 0;
				if (toggle = '0') then
					spongeframe <= spongeframe + 1;
					if (spongeframe = 32) then
						toggle <= '1';
					end if;
				else
					spongeframe <= spongeframe - 1;
					if (spongeframe = 1) then
						toggle <= '0';
					end if;
				end if;

				
				if(colorToggle = "000") then
					scoreColor(11 downto 8) <= std_logic_vector(unsigned(scoreColor(11 downto 8)) + 1);
					if(scoreColor(11 downto 8) = "1110") then
						colorToggle <= "001";
					end if;
				elsif (colorToggle = "001") then
					scoreColor(7 downto 4) <= std_logic_vector(unsigned(scoreColor(7 downto 4)) + 1);
					if(scoreColor(7 downto 4) = "1110") then
						colorToggle <= "010";
					end if;
				elsif(colorToggle = "010") then
					scoreColor(11 downto 8) <= std_logic_vector(unsigned(scoreColor(11 downto 8)) - 1);
					if(scoreColor(11 downto 8) = "0001") then
						colorToggle <= "011";
					end if;
				elsif (colorToggle = "011") then
					scoreColor(3 downto 0) <= std_logic_vector(unsigned(scoreColor(3 downto 0)) + 1);
					if(scoreColor(3 downto 0) = "1110") then
						colorToggle <= "100";
					end if;
				elsif(colorToggle = "100") then
					scoreColor(7 downto 4) <= std_logic_vector(unsigned(scoreColor(7 downto 4)) - 1);
					if(scoreColor(7 downto 4) = "0001") then
						colorToggle <= "101";
					end if;	
				elsif (colorToggle = "101") then
					scoreColor(11 downto 8) <= std_logic_vector(unsigned(scoreColor(11 downto 8)) + 1);
					if(scoreColor(11 downto 8) = "1110") then
						colorToggle <= "110";
					end if;
				elsif(colorToggle = "110") then
					scoreColor(3 downto 0) <= std_logic_vector(unsigned(scoreColor(3 downto 0)) - 1);
					if(scoreColor(3 downto 0) = "0001") then
						colorToggle <= "001";
					end if;
				end if; -- Increment colour level


			else
				spongecount <= spongecount + 1;
			end if;
        end if;
    end process;	

	--pix_index <= draw_index;


	-- button debounce stuff
	process(reset, button(0))
	begin
		if (reset = '0') then
			scoretype(3 downto 0) <= "0000";
			hit(0) <= '0';
			score0 <= (others => '0');
		elsif (falling_edge(button(0))) then
			
			if (draw3 - 160 >= 390 and draw3 - 160 < 410 and hit(0) = '0' and notes(draw_index)(0) = '1') then 
				scoretype(3) <= '1';
				hit(0) <= '1';
				score0 <= score0 + 5;
			elsif (draw3 - 160 >= 370 and draw3 - 160 < 430 and hit(0) = '0' and notes(draw_index)(0) = '1') then
				scoretype(2) <= '1';
				hit(0) <= '1';
				score0 <= score0 + 3;
			elsif (draw3 - 160 >= 345 and draw3 - 160 < 455 and hit(0) = '0' and notes(draw_index)(0) = '1') then
				scoretype(1) <= '1';
				hit(0) <= '1';
				score0 <= score0 + 1;
			elsif (hit(0) = '0' and notes(draw_index)(0) = '0') then
				scoretype(0) <= '1';
				hit(0) <= '1';
			end if;

			if (state_r = DONE1 or state_r = DONE2) then
				score0 <= (others =>'0');
			end if;

		end if;

		if (draw3 - 160 = 320) then
			hit(0) <= '0';
			scoretype(3 downto 0) <= "0000";
		end if;
		
	end process;		

	process(reset, button(1))
	begin
		if (reset = '0') then
			scoretype(7 downto 4) <= "0000";
			hit(1) <= '0';
			score1 <= (others => '0');
		elsif (falling_edge(button(1))) then
			if (draw3 - 160 >= 390 and draw3 - 160 < 410 and hit(1) = '0' and notes(draw_index)(1) = '1') then 
				scoretype(7) <= '1';
				hit(1) <= '1';
				score1 <= score1 + 5;
			elsif (draw3 - 160 >= 370 and draw3 - 160 < 430 and hit(1) = '0' and notes(draw_index)(1) = '1') then
				scoretype(6) <= '1';
				hit(1) <= '1';
				score1 <= score1 + 3;
			elsif (draw3 - 160 >= 345 and draw3 - 160 < 455 and hit(1) = '0' and notes(draw_index)(1) = '1') then
				scoretype(5) <= '1';
				hit(1) <= '1';
				score1 <= score1 + 1;
			elsif (hit(1) = '0' and notes(draw_index)(1) = '0') then
				scoretype(4) <= '1';
				hit(1) <= '1';
			end if;

			if (state_r = DONE1 or state_r = DONE2) then
				score1 <= (others =>'0');
			end if;
		end if;

		if (draw3 - 160 = 320) then
			hit(1) <= '0';
			scoretype(7 downto 4) <= "0000";
		end if;
	end process;

	process(reset, button(2))
	begin
		if (reset = '0') then
			scoretype(11 downto 8) <= "0000";
			hit(2) <= '0';
			score2 <= (others => '0');
		elsif (falling_edge(button(2))) then
			if (draw3 - 160 >= 390 and draw3 - 160 < 410 and hit(2) = '0' and notes(draw_index)(2) = '1') then 
				scoretype(11) <= '1';
				hit(2) <= '1';
				score2 <= score2 + 5;
			elsif (draw3 - 160 >= 370 and draw3 - 160 < 430 and hit(2) = '0' and notes(draw_index)(2) = '1') then
				scoretype(10) <= '1';
				hit(2) <= '1';
				score2 <= score2 + 3;
			elsif (draw3 - 160 >= 345 and draw3 - 160 < 455 and hit(2) = '0' and notes(draw_index)(2) = '1') then
				scoretype(9) <= '1';
				hit(2) <= '1';
				score2 <= score2 + 1;
			elsif (hit(2) = '0' and notes(draw_index)(2) = '0') then
				scoretype(8) <= '1';
				hit(2) <= '1';
			end if;

			if (state_r = DONE1 or state_r = DONE2) then
				score2 <= (others =>'0');
			end if;
		end if;

		if (draw3 - 160 = 320) then
			hit(2) <= '0';
			scoretype(11 downto 8) <= "0000";
		end if;
	end process;

	process(reset, button(3))
	begin
		if (reset = '0') then
			scoretype(15 downto 12) <= "0000";
			hit(3) <= '0';
			score3 <= (others => '0');
		elsif (falling_edge(button(3))) then
			if (draw3 - 160 >= 390 and draw3 - 160 < 410 and hit(3) = '0' and notes(draw_index)(3) = '1') then 
				scoretype(15) <= '1';
				hit(3) <= '1';
				score3 <= score3 + 5;
			elsif (draw3 - 160 >= 370 and draw3 - 160 < 430 and hit(3) = '0' and notes(draw_index)(3) = '1') then
				scoretype(14) <= '1';
				hit(3) <= '1';
				score3 <= score3 + 3;
			elsif (draw3 - 160 >= 345 and draw3 - 160 < 455 and hit(3) = '0' and notes(draw_index)(3) = '1') then
				scoretype(13) <= '1';
				hit(3) <= '1';
				score3 <= score3 + 1;
			elsif (hit(3) = '0' and notes(draw_index)(3) = '0') then
				scoretype(12) <= '1';
				hit(3) <= '1';
			end if;

			if (state_r = DONE1 or state_r = DONE2) then
				score3 <= (others =>'0');
			end if;
		end if;

		if (draw3 - 160 = 320) then
			hit(3) <= '0';
			scoretype(15 downto 12) <= "0000";
		end if;
	end process;
	

	process(reset, clk_pix)
	begin
		if(reset = '0') then
			completemiss <= "0000";
			complete_debounce <= "0000";
			completemiss_score <= (others => '0');
		elsif(rising_edge(clk_pix)) then
			if (draw3 - 160 = 455 and hit(0) = '0' and complete_debounce(0) <= '0' and notes(draw_index)(0) = '1') then
				completemiss(0) <= '1';
				complete_debounce(0) <= '1';
				completemiss_score <= completemiss_score + 1;
			elsif (draw3 - 160 = 455 and hit(1) = '0' and complete_debounce(1) <= '0' and notes(draw_index)(1) = '1') then
				completemiss(1) <= '1';
				complete_debounce(1) <= '1';
				completemiss_score <= completemiss_score + 1;
			elsif (draw3 - 160 = 455 and hit(2) = '0' and complete_debounce(2) <= '0' and notes(draw_index)(2) = '1') then
				completemiss(2) <= '1';
				complete_debounce(2) <= '1';
				completemiss_score <= completemiss_score + 1;
			elsif (draw3 - 160 = 455 and hit(3) = '0' and complete_debounce(3) <= '0' and notes(draw_index)(3) = '1') then
				completemiss(3) <= '1';
				complete_debounce(3) <= '1';
				completemiss_score <= completemiss_score + 1;
			end if;

			if (state_r = DONE1 or state_r = DONE2) then
				completemiss_score <= (others =>'0');
			end if;

		end if;
		
		if (draw3 - 160 = 320) then
			complete_debounce <= "0000";
			completemiss <= "0000";
		end if;

		--no latch?
		--complete_debounce(3 downto 2) <= "00";
		--completemiss(3 downto 2) <= "00";

	end process;

	process(reset, clk_pix)
	begin
		if(reset = '0') then
			scoreDebug <= "0000";
			scoreIndex <= 0;
		elsif(rising_edge(clk_pix)) then
			if(scoretype(0) = '1' or scoretype(4) = '1' or scoretype(8) = '1' or scoretype(12) = '1' or completemiss(0) = '1' or completemiss(1) = '1' or completemiss(2) = '1' or completemiss(3) = '1') then
				scoreDebug <= "0001";
				scoreIndex <= 192;
			elsif(scoretype(1) = '1' or scoretype(5) = '1' or scoretype(9) = '1' or scoretype(13) = '1') then
				scoreDebug <= "0010";
				scoreIndex <= 128;
			elsif(scoretype(2) = '1' or scoretype(6) = '1' or scoretype(10) = '1' or scoretype(14) = '1') then
				scoreDebug <= "0011";
				scoreIndex <= 64;
			elsif(scoretype(3) = '1' or scoretype(7) = '1' or scoretype(11) = '1' or scoretype(15) = '1') then
				scoreDebug <= "0100";
				scoreIndex <= 0;
			end if;
		end if;
	end process;
	
	
	--perfect <= std_logic_vector(scoreDebug);
	--great(0) <= scoretype(2);
	--good(0) <= scoretype(1);
	--miss(0) <= scoretype(0) or completemiss(0);

	--score_disp <= completemiss_score;

	process(score0, score1, score2, score3, completemiss_score) 
	begin
		if (score0 + score1 + score2 + score3 < completemiss_score) then
			score_disp <= (others => '0');
		else
			score_disp <= (score0 + score1 + score2 + score3) - completemiss_score;
		end if;
	end process;

	perfect <= std_logic_vector(score_disp(15 downto 12));
	great <= std_logic_vector(score_disp(11 downto 8));
	good <= std_logic_vector(score_disp(7 downto 4));
	miss <= std_logic_vector(score_disp(3 downto 0) );

    -- Paint colour: yellow lines, blue background
    process(clk_pix)
    begin
		sprite_out <= (others => '0');
		address <= (others => '0');
		logo_address <= (others => '0');
		rating_address <= (others => '0');
		sponge_address <= (others => '0');
		mb_address <= (others => '0');
		introscreen_address <= (others => '0');
		
		if (state_r = START or state_r = DONE1 or state_r = DONE2) then
			if (sx >= 100 and sx < 100 + 384 and sy >= 100 and sy < 100 + 168 and (sx-100)+384*(sy-100) >= 0) then
				logo_address <= std_logic_vector(to_unsigned(((sx-100)+384*((sy-100)/2))/2,14));
				
				paint_r <= logo_q(11 downto 8);
				paint_g <= logo_q(7 downto 4);
				paint_b <= logo_q(3 downto 0);
			elsif (sx >= 100 and sx < 100 + 164 and sy >= 300 and sy < 300 + 88 and (sx-100)+164*(sy-300) >= 0) then
				introscreen_address <= std_logic_vector(to_unsigned(((sx-100)+164*((sy-300)/2))/2,12));
				
				paint_r <= introscreen_q(11 downto 8);
				paint_g <= introscreen_q(7 downto 4);
				paint_b <= introscreen_q(3 downto 0);
			else
				paint_r <= "0000"; -- white
				paint_g <= "0000";
				paint_b <= "0000";
			end if;

		elsif (sy <= draw3 +2 - 160 and sy >= draw3 -2 - 160 and sx < 256 and guideline = '1') then
			paint_r <= "1111"; -- white
			paint_g <= "1111";
			paint_b <= "1111";

		elsif ((sx >= 0 and sx < 0 + 2 and sy >= 400 and sy < 464) or (sx >= 0 + 64 - 2 and sx < 0 + 64 and sy >= 400 and sy < 464) or 
			(sx >= 0 and sx < 0 + 64 and sy >= 400 and sy < 402) or (sx >= 0 and sx < 0 + 64 and sy >= 462 and sy < 464) or
			(sx >= 0 + 8 and sx < 0 + 64 - 8 and sy >= 400 + 8 and sy < 464 - 8 and button(3) = '0')) then
			paint_r <= "1010"; 
            paint_g <= "0011";
            paint_b <= "1110";
		
		elsif ((sx >= 64 and sx < 66 and sy >= 400 and sy < 464) or (sx >= 126 and sx < 128 and sy >= 400 and sy < 464) or 
			(sx >= 64 and sx < 128 and sy >= 400 and sy < 402) or (sx >= 64 and sx < 128 and sy >= 462 and sy < 464) or
			(sx >= 64 + 8 and sx < 128 - 8 and sy >= 400 + 8 and sy < 464 - 8 and button(2) = '0')) then
			paint_r <= "1101"; 
            paint_g <= "1101";
            paint_b <= "0110";

		elsif ((sx >= 128 and sx < 128 + 2 and sy >= 400 and sy < 464) or (sx >= 128 + 64 - 2 and sx < 128 + 64 and sy >= 400 and sy < 464) or 
			(sx >= 128 and sx < 128 + 64 and sy >= 400 and sy < 402) or (sx >= 128 and sx < 128 + 64 and sy >= 462 and sy < 464) or
			(sx >= 128 + 8 and sx < 128 + 64 - 8 and sy >= 400 + 8 and sy < 464 - 8 and button(1) = '0')) then
			paint_r <= "0010"; 
            paint_g <= "0110";
            paint_b <= "1011";

		elsif ((sx >= 192 and sx < 192 + 2 and sy >= 400 and sy < 464) or (sx >= 192 + 64 - 2 and sx < 192 + 64 and sy >= 400 and sy < 464) or 
			(sx >= 192 and sx < 192 + 64 and sy >= 400 and sy < 402) or (sx >= 192 and sx < 192 + 64 and sy >= 462 and sy < 464) or
			(sx >= 192 + 8 and sx < 192 + 64 - 8 and sy >= 400 + 8 and sy < 464 - 8 and button(0) = '0')) then
			paint_r <= "1010"; 
            paint_g <= "0001";
            paint_b <= "0101";
		

		elsif (sx >= 0 and sx < 64 and sy >= 400 and sy < 464 and button(3) = '0') or  
			(sx >= 64 and sx < 128 and sy >= 400 and sy < 464 and button(2) = '0') or 
			(sx >= 128 and sx < 192 and sy >= 400 and sy < 464 and button(1) = '0') or 
			(sx >= 192 and sx < 256 and sy >= 400 and sy < 464 and button(0) = '0') then
			paint_r <= "1111"; 
            paint_g <= "1111";
            paint_b <= "1111";

		elsif (sy >= 320 and sy < 322 and sx < 256 and guideline = '1') then --starting line

			paint_r <= "1111"; 
            paint_g <= "0000";
            paint_b <= "1111";

		elsif (sy >= 390 and sy < 392 and sx < 256 and guideline = '1') or (sy >= 410 and sy < 412 and sx < 256 and guideline = '1')  then --perfect
			paint_r <= "1111"; 
            paint_g <= "0000";
            paint_b <= "0000";

		elsif (sy >= 370 and sy < 372 and sx < 256 and guideline = '1') or (sy >= 430 and sy < 432 and sx < 256 and guideline = '1')  then --great
			paint_r <= "0000"; 
			paint_g <= "1111";
			paint_b <= "0000";

		elsif (sy >= 345 and sy < 347 and sx < 256 and guideline = '1') or (sy >= 455 and sy < 457 and sx < 256 and guideline = '1')  then --good
			paint_r <= "0000"; 
			paint_g <= "0000";
			paint_b <= "1111";

		elsif (sy >= 400 and sy < 402 and sx < 256 and guideline = '1')  then --center line
			paint_r <= "1001";
			paint_g <= "0011";
			paint_b <= "1100";

		elsif (sx >= 256 + 16 and sx < 256 + 16 + 2 and sy >= 208 and sy < 464) or (sx >= 256 + 32 + 16 and sx < 256 + 32 + 16 + 2 and sy >= 208 and sy < 464) or
			(sx >= 256 + 16 and sx < 256 + 16 + 32 and sy >= 208 and sy < 210) or (sx >= 256 + 16 and sx < 256 + 16 + 32 and sy >= 462 and sy < 464) or
			(sx >= 256 + 16 and sx < 256 + 16 + 32 and sy >= 240 and sy < 240 + 2) or (sx >= 256 + 16 and sx < 256 + 16 + 32 and sy >= 272 and sy < 272 + 2) or
			(sx >= 256 + 16 and sx < 256 + 16 + 32 and sy >= 304 and sy < 304 + 2) or (sx >= 256 + 16 and sx < 256 + 16 + 32 and sy >= 336 and sy < 336 + 2) or
			(sx >= 256 + 16 and sx < 256 + 16 + 32 and sy >= 368 and sy < 368 + 2) or (sx >= 256 + 16 and sx < 256 + 16 + 32 and sy >= 400 and sy < 400 + 2) or
			(sx >= 256 + 16 and sx < 256 + 16 + 32 and sy >= 432 and sy < 432 + 2) then --score bar

			paint_r <= "1111";
			paint_g <= "1111";
			paint_b <= "1111";

		elsif (sx >= 256 + 16 and sx < 256 + 16 + 32 and sy >= 464 - to_integer(score_disp)*2  and sy < 464 and sy >= 208) then 

			paint_r <= scoreColor(11 downto 8);
			paint_g <= scoreColor(7 downto 4);
			paint_b <= scoreColor(3 downto 0);

		elsif (sy >= draw0 - 160 and sy < draw0 - 96 and sx < 256) then

			if (notes(draw_index+3)(3) = '1' and sx >= 0 and sx < 64 and (sx)+64*(sy-(draw0-160)) >= 0) then
				address <= std_logic_vector(to_unsigned(((sx)+64*(sy-(draw0-160))),12));
				sprite_out <= q(47 downto 36);
			elsif (notes(draw_index+3)(2) = '1' and sx >= 64 and sx < 128 and (sx-64)+64*(sy-(draw0-160)) >= 0) then
				address <= std_logic_vector(to_unsigned(((sx-64)+64*(sy-(draw0-160))),12));
				sprite_out <= q(35 downto 24);
			elsif (notes(draw_index+3)(1) = '1' and sx >= 128 and sx < 192 and (sx-128)+64*(sy-(draw0-160)) >= 0) then
				address <= std_logic_vector(to_unsigned(((sx-128)+64*(sy-(draw0-160))),12));
				sprite_out <= q(23 downto 12);
			elsif (notes(draw_index+3)(0) = '1' and sx >= 192 and sx < 256 and (sx-192)+64*(sy-(draw0-160)) >= 0) then
				address <= std_logic_vector(to_unsigned(((sx-192)+64*(sy-(draw0-160))),12));
				sprite_out <= q(11 downto 0);
			else
				sprite_out <= (others => '0');
			end if;
				
			paint_r <= sprite_out(11 downto 8);
			paint_g <= sprite_out(7 downto 4);
			paint_b <= sprite_out(3 downto 0);
		
		elsif (sy >= draw1 - 160 and sy < draw1 - 96 and sx < 256) then
		
			if (notes(draw_index+2)(3) = '1' and sx >= 0 and sx < 64 and (sx)+64*(sy-(draw1-160)) >= 0) then
				address <= std_logic_vector(to_unsigned(((sx)+64*(sy-(draw1-160))),12));
				sprite_out <= q(47 downto 36);
			elsif (notes(draw_index+2)(2) = '1' and sx >= 64 and sx < 128 and (sx-64)+64*(sy-(draw1-160)) >= 0) then
				address <= std_logic_vector(to_unsigned(((sx-64)+64*(sy-(draw1-160))),12));
				sprite_out <= q(35 downto 24);
			elsif (notes(draw_index+2)(1) = '1' and sx >= 128 and sx < 192 and (sx-128)+64*(sy-(draw1-160)) >= 0) then
				address <= std_logic_vector(to_unsigned(((sx-128)+64*(sy-(draw1-160))),12));
				sprite_out <= q(23 downto 12);
			elsif (notes(draw_index+2)(0) = '1' and sx >= 192 and sx < 256 and (sx-192)+64*(sy-(draw1-160)) >= 0) then
				address <= std_logic_vector(to_unsigned(((sx-192)+64*(sy-(draw1-160))),12));
				sprite_out <= q(11 downto 0);
			else
				sprite_out <= (others => '0');
			end if;
				
			paint_r <= sprite_out(11 downto 8);
			paint_g <= sprite_out(7 downto 4);
			paint_b <= sprite_out(3 downto 0);
		
		elsif (sy >= draw2 - 160 and sy < draw2 - 96 and sx < 256 ) then
		
			if (notes(draw_index+1)(3) = '1' and sx >= 0 and sx < 64 and (sx)+64*(sy-(draw2-160)) >= 0) then
				address <= std_logic_vector(to_unsigned(((sx)+64*(sy-(draw2-160))),12));
				sprite_out <= q(47 downto 36);
			elsif (notes(draw_index+1)(2) = '1' and sx >= 64 and sx < 128 and (sx-64)+64*(sy-(draw2-160)) >= 0) then
				address <= std_logic_vector(to_unsigned(((sx-64)+64*(sy-(draw2-160))),12));
				sprite_out <= q(35 downto 24);
			elsif (notes(draw_index+1)(1) = '1' and sx >= 128 and sx < 192 and (sx-128)+64*(sy-(draw2-160)) >= 0) then
				address <= std_logic_vector(to_unsigned(((sx-128)+64*(sy-(draw2-160))),12));
				sprite_out <= q(23 downto 12);
			elsif (notes(draw_index+1)(0) = '1' and sx >= 192 and sx < 256 and (sx-192)+64*(sy-(draw2-160)) >= 0) then
				address <= std_logic_vector(to_unsigned(((sx-192)+64*(sy-(draw2-160))),12));
				sprite_out <= q(11 downto 0);
			else
				sprite_out <= (others => '0');
			end if;
				
			paint_r <= sprite_out(11 downto 8);
			paint_g <= sprite_out(7 downto 4);
			paint_b <= sprite_out(3 downto 0);
		

		elsif (sy >= draw3 - 160 and sy < draw3 - 96 and sx < 256) then

			if (notes(draw_index)(3) = '1' and sx >= 0 and sx < 64 and (sx)+64*(sy-(draw3-160)) >= 0) then
				address <= std_logic_vector(to_unsigned(((sx)+64*(sy-(draw3-160))),12));
				sprite_out <= q(47 downto 36);
			elsif (notes(draw_index)(2) = '1' and sx >= 64 and sx < 128 and (sx-64)+64*(sy-(draw3-160)) >= 0) then
				address <= std_logic_vector(to_unsigned(((sx-64)+64*(sy-(draw3-160))),12));
				sprite_out <= q(35 downto 24);
			elsif (notes(draw_index)(1) = '1' and sx >= 128 and sx < 192 and (sx-128)+64*(sy-(draw3-160)) >= 0) then
				address <= std_logic_vector(to_unsigned(((sx-128)+64*(sy-(draw3-160))),12));
				sprite_out <= q(23 downto 12);
			elsif (notes(draw_index)(0) = '1' and sx >= 192 and sx < 256 and (sx-192)+64*(sy-(draw3-160)) >= 0) then
				address <= std_logic_vector(to_unsigned(((sx-192)+64*(sy-(draw3-160))),12));
				sprite_out <= q(11 downto 0);
			else
				sprite_out <= (others => '0');
			end if;
				
			paint_r <= sprite_out(11 downto 8);
			paint_g <= sprite_out(7 downto 4);
			paint_b <= sprite_out(3 downto 0);

		elsif (sx >= 256 and sy < 168 and (sx-256)+384*(sy) >= 0) then
			logo_address <= std_logic_vector(to_unsigned(((sx-256)+384*(sy/2))/2,14));
			
			paint_r <= logo_q(11 downto 8);
			paint_g <= logo_q(7 downto 4);
			paint_b <= logo_q(3 downto 0);
	
		elsif (sx >= 320 and sx < 320 + 256 and sy >= 200 and sy < 200+64 and (sx-320)+256*(sy-200) >= 0) then
			rating_address <= std_logic_vector(to_unsigned(((sx-320)+256*((sy+scoreIndex-200)/4))/4,12));

			paint_r <= rating_q(11 downto 8);
			paint_g <= rating_q(7 downto 4);
			paint_b <= rating_q(3 downto 0);

		elsif (sx >= 512 and sx < 512 + 64 and sy >= 300 and sy < 300+64 and (sx-512)+64*(sy-300) >= 0) then
			mb_address <= std_logic_vector(to_unsigned(((sx-508)+64*((sy-300))),12));

			paint_r <= mb_q(11 downto 8);
			paint_g <= mb_q(7 downto 4);
			paint_b <= mb_q(3 downto 0);

		elsif (sx >= 320 and sx < 320 + 188 and sy >= 300 and sy < 300+188 and (sx-320)+47*10*(sy-300) >= 0) then
			sponge_address <= std_logic_vector(to_unsigned((((sx-320)+188*((sy-300)/4))/4)+2209*spongeframe,17));

			paint_r <= sponge_q(11 downto 8);
			paint_g <= sponge_q(7 downto 4);
			paint_b <= sponge_q(3 downto 0);

        else
            paint_r <= "0000"; -- Black background
            paint_g <= "0000";
            paint_b <= "0000";
        end if;
    end process;


    
	

	process(de, sy, sx)	
	begin	
		--Signal that enables to display data on the screen
		if(de = '1') then
			R <= paint_r;
			G <= paint_g;
			B <= paint_b;	
		else
			-- If de = 0, no color has to be displayed
			R <= (others => '0');
			G <= (others => '0');
			B <= (others => '0');	
		end if;
	end process;

	
	

end image_generator_arch;
			

	
