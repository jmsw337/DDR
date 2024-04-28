library ieee;
use ieee.std_logic_1164.all;

entity VGA is

	generic(
	
		div:integer := 2;
		div_paddle : integer := 415000;
		
		div_ball1 : integer := 415000;
		div_ball2 : integer := 370000;
		div_ball3 : integer := 310000;
		div_ball4 : integer := 250000;
	
		Ha: integer := 96;
		Hb: integer := 144;
		Hc: integer := 784;
		Hd: integer := 800;
		Va: integer := 2;
		Vb: integer := 35;
		Vc: integer := 515;
		Vd: integer := 525;
		paddlesizeH: integer := 2;
		paddlesizeV: integer := 30);

	port(
			clk : in std_logic;
			reset: in std_logic;
			
			Hsync, Vsync : buffer std_logic;
			--direction_switch: in std_logic_vector(3 downto 0);
			button		: in std_logic_vector(3 downto 0);
			guideline 	: in std_logic; 
			start_s 		: in std_logic;
			--seg1 	: out std_logic_vector(6 downto 0);
			--seg2		: out std_logic_vector(6 downto 0);
			--bar		: out std_logic;

			m_button : in std_logic_vector(1 downto 0);

			led0    : out std_logic_vector(6 downto 0);
			led1    : out std_logic_vector(6 downto 0);
			led2    : out std_logic_vector(6 downto 0);
			led3    : out std_logic_vector(6 downto 0);
			
			led : out std_logic_vector(9 downto 0);
			
			R, G, B 		 : out std_logic_vector(3 downto 0);

			debug_pin : out std_logic);

end VGA;



architecture VGA_arch of VGA is

	signal clk_pix: std_logic;
	signal Hactive, Vactive, de : std_logic;
	signal paddle_clk, ball_clk : std_logic;
	signal score  : integer;

	signal perfect : std_logic_vector(3 downto 0);
	signal great : std_logic_vector(3 downto 0);
	signal good : std_logic_vector(3 downto 0);
	signal miss : std_logic_vector(3 downto 0);


	
	--Pin assignments
	attribute chip_pin : string;
	
	attribute chip_pin of clk	       : signal is "N14";
	attribute chip_pin of reset	       : signal is "F15";
	
	--attribute chip_pin of direction_switch : signal is "C10,C11,C12,A12";
	--attribute chip_pin of button       : signal is "C10, C11, A7, B8";
	attribute chip_pin of button       : signal is "AA2, Y3, Y4, Y5";
	attribute chip_pin of guideline    : signal is "B14";
	attribute chip_pin of start_s : signal is "C10";
	
	attribute chip_pin of Hsync	       : signal is "N3";
	attribute chip_pin of Vsync	       : signal is "n1";
	
	--attribute chip_pin of R		       : signal is "AA1, V1, Y2, Y1";
	--attribute chip_pin of G		       : signal is "W1, T2, R2, R1";
	--attribute chip_pin of B		       : signal is "P1, T1, P4, N2";
	attribute chip_pin of R		       : signal is "Y1, Y2, V1, AA1";
	attribute chip_pin of G		       : signal is "R1, R2, T2, W1";
	attribute chip_pin of B		       : signal is "N2, P4, T1, P1";

	--attribute chip_pin of seg1	       : signal is 
 	--attribute chip_pin of seg2	       : signal is "C17,D17,E16,C16,C15,E15,C14";
	--attribute chip_pin of bar	       : signal is "B17";

	attribute chip_pin of led0 		: signal is "C17,D17,E16,C16,C15,E15,C14";
	attribute chip_pin of led1 		: signal is "B17,A18,A17,B16,E18,D18,C18";
	attribute chip_pin of led2 		: signal is "B22,C22,B21,A21,B19,A20,B20";
	attribute chip_pin of led3 		: signal is "E17,D19,C20,C19,E21,E22,F21";

	attribute chip_pin of m_button : signal is "W10, W9";
	attribute chip_pin of led : signal is "A8, A9, A10, B10, D13, C13, E14, D14, A11, B11";
	attribute chip_pin of debug_pin : signal is "V10";



			
begin

	U0: entity work.div_gen
	 
		generic map (div => div)
		port map		(clk_in => clk, reset => reset, clk_out => clk_pix);
		
	u1: entity work.sync_generator
	
		generic map(Ha => Ha,
						Hb => Hb,
						Hc => Hc,
						Hd => Hd,
						Va => Va,
						Vb => Vb,
						Vc => Vc,
						Vd => Vd)
						
		port map(clk_pix => clk_pix,
					reset	=> reset,
					Hsync	=> Hsync,
					Vsync	=> Vsync,
					Hactive	=> Hactive,
					Vactive	=> Vactive,
					de 	=> de);
					
	u2: entity work.image_generator
	
		generic map(Ha => Ha,
						Hb => Hb,
						Hc => Hc,
						Hd => Hd,
						Va => Va,
						Vb => Vb,
						Vc => Vc,
						Vd => Vd,
						PVsize => paddlesizeV,
						PHsize => paddlesizeH)
		
		port map(		clk_pix	=> clk_pix,
					--paddle_clk	=> paddle_clk,
					--ball_clk	=> ball_clk,
					reset		=> reset,
					Hactive		=> Hactive,
					Vactive 	=> Vactive,
					Hsync		=> Hsync,
					Vsync		=> Vsync,
					de		=> de,
					--direction_switch=> direction_switch,
					button	=> button,
					m_button => m_button,
					start_s => start_s,
					guideline => guideline,
					score		=> score,
					perfect 	=> perfect,
					great 		=> great,
					good 		=> good,
					miss		=> miss,
					--score2		=> score2,
					R		=> R,
					G		=> G,
					B		=> B,
					led 	=> led,
					debug_pin => debug_pin
					);
					
		u3: entity work.div_gen
					generic map (div => div_paddle)
					port map		(clk_in => clk, reset => reset, clk_out => paddle_clk);

		u5: entity work.div_gen
				generic map (div => div_ball1)
				port map		(clk_in => clk, reset => reset, clk_out => ball_clk);

				--u4: entity work.score_display
				--port map		(score1 => score, score2 => score, seg1 => seg1, seg2 => seg2, bar => bar);

		U_LED0 : entity work.decoder7seg
			port map(
				input => perfect,
				output => led0
			);

		U_LED1 : entity work.decoder7seg
		port map(
			input => great,
			output => led1
		);

		U_LED2 : entity work.decoder7seg
			port map(
				input => good,
				output => led2
			);

		U_LED3 : entity work.decoder7seg
		port map(
			input => miss,
			output => led3
		);
					
end VGA_arch;
