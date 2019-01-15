-module(mp3player).
-compile([export_all]).
-include_lib("wx/include/wx.hrl").

-record(state,
	{
	  name,
    value
	 }).
write() ->

    receive
        {play} ->
						%io:format("lol\n"),
            io:format("\nplaying ~p \nVol: ~p Mute: ~p ~n", [get_curr_song(),get_vol(),is_mute()]),
            write();
        {pause} ->
            io:format("\npause ~p \nVol: ~p Mute: ~p ~n", [get_curr_song(),get_vol(),is_mute()]),
            write();
        {volume} ->
            io:format("\nVol: ~p Mute: ~p ~n", [get_vol(),is_mute()]),
            write()

    end.

  get_key_event(WritePid) ->

      receive
          {play} -> %112
              WritePid ! {play},
              get_key_event(WritePid);
          {pause} -> %115
              WritePid ! {pause},
              get_key_event(WritePid);
          {next} -> %110
              play_next_song(WritePid),
              get_key_event(WritePid);
					{prev} -> %110
	            play_prev_song(WritePid),
	            get_key_event(WritePid);
          {up} -> %43
              rise_vol(WritePid),
              get_key_event(WritePid);
          {down} -> %45
              lower_vol(WritePid),
              get_key_event(WritePid);
          {mute} -> %109
              update_mute(WritePid),
              get_key_event(WritePid);
					{change_playlist, Index} ->
							play_next_playlist(WritePid,Index),
							get_key_event(WritePid)

      end.



%music() ->
%     os:cmd("ffplay /home/paulina/semestrV/basic_mp3_player/m.mp3").

readlines(Path) ->
       {ok, Device} = file:open(Path, [read]),
       try get_all_lines(Device)
         after file:close(Device)
       end.

get_all_lines(Device) ->
       case io:get_line(Device, "") of
           eof  -> [];
           Line -> Line ++ get_all_lines(Device)
       end.

update_curr_song(Title) ->
  Path = "/home/paulina/semestrV/basic_mp3_player/current_song.txt",
  file:write_file(Path, Title).

get_curr_song() ->
  Path = "/home/paulina/semestrV/basic_mp3_player/current_song.txt",
  Title = readlines(Path),
  Title.

update_all_songs(Title) ->
  Path = "/home/paulina/semestrV/basic_mp3_player/all_songs.txt",
  file:write_file(Path, "\n"++Title, [append]).

get_songs() ->
	Playlist = get_curr_playlist(),
  Path = "/home/paulina/semestrV/basic_mp3_player/"++Playlist++".txt",
  Songs = readlines(Path),
  string:lexemes(Songs,"\n").

get_all_playlists()->
	Path = "/home/paulina/semestrV/basic_mp3_player/playlists.txt",
	Playlist = readlines(Path),
	string:lexemes(Playlist,"\n").

update_curr_playlist(Index)->
	Path = "/home/paulina/semestrV/basic_mp3_player/current_playlist.txt",
	Playlists = get_all_playlists(),
	Playlist = lists:nth(Index+1, Playlists),
	file:write_file(Path, Playlist),
	Song = get_curr_song(),
	Songs = get_songs(),
	case lists:member(Song, Songs) of
		false ->
			[First|_] = Songs,
			update_curr_song(First);
		true ->  ok
	end
	.


get_curr_playlist()->
	Path = "/home/paulina/semestrV/basic_mp3_player/current_playlist.txt",
  Playlist = readlines(Path),
  Playlist.

play_next_playlist(Pid,Index)->
	update_curr_playlist(Index),
	Pid ! {Pid}.


search_next(Val, [Val, Next|_],_)-> Next;
search_next(Val, [_|T], L)-> search_next(Val, T,L);
search_next(_,[],[First|_])-> First.

search_prev(Val, [Val|T])-> lists:last(T);
search_prev(Val, [Prev, Val|_])-> Prev;
search_prev(Val, [_|T])-> search_prev(Val, T).

get_next_song() ->
  Songs = get_songs(),
  Next_song = search_next(get_curr_song(),Songs,Songs),
  Next_song.

get_prev_song() ->
  Songs = get_songs(),
  Prev_song = search_prev(get_curr_song(),Songs),
  Prev_song.

play_next_song(Pid) ->
  timer:sleep(10),
  Song = get_next_song(),
  update_curr_song(Song),
  Pid ! {play}.

play_prev_song(Pid) ->
  timer:sleep(10),
  Song = get_prev_song(),
  update_curr_song(Song),
  Pid ! {play}.

get_speaker() ->
  Path = "/home/paulina/semestrV/basic_mp3_player/speaker.txt",
  Speaker = readlines(Path),
  string:lexemes(Speaker,"\n").

is_mute() ->
  [IsMute|_] = get_speaker(),
  IsMute.

get_vol() ->
  [_,Vol_str|_] = get_speaker(),
  {Vol,_} = string:to_integer(Vol_str),
  Vol.

get_opposite_Mute(<<"T">>) -> "F";
get_opposite_Mute(<<"F">>) -> "T";
get_opposite_Mute(A) -> A.



update_mute(Pid) ->
  Path = "/home/paulina/semestrV/basic_mp3_player/speaker.txt",
  {ok, Content} = file:read_file(Path),
  [IsMute | Tail] = binary:split(Content, <<"\n">>),
  NewContent = [get_opposite_Mute(IsMute), <<"\n">> | Tail],
  file:write_file(Path, NewContent),
  Pid ! {volume}.

get_corr_vol(51) -> 50;
get_corr_vol(-1) -> 0;
get_corr_vol(Vol) -> Vol.

rise_vol(Pid) ->
  Path = "/home/paulina/semestrV/basic_mp3_player/speaker.txt",
  NewContent = is_mute()++"\n"++integer_to_list(get_corr_vol(get_vol()+1)),
  file:write_file(Path, NewContent),
  Pid ! {volume}.

lower_vol(Pid) ->
  Path = "/home/paulina/semestrV/basic_mp3_player/speaker.txt",
  NewContent = is_mute()++"\n"++integer_to_list(get_corr_vol(get_vol()-1)),
  file:write_file(Path, NewContent),
  Pid ! {volume}.

handle_event(#wx{event = #wxKey{type = key_down}}, State) ->
    Code = wxKeyEvent:getKeyCode(),
    Pi = State#state.value,
    Pi ! {Code},
    {noreply, State}.

run() ->
    Pid2 = spawn(?MODULE, write, []),
    %Pid2 ! {play},
    %Pid2 ! {pause},
    %play_next_song(Pid2),
    %lower_vol(Pid2),
    State=#state{name="Pid2", value=Pid2},
    %Pid3 = spawn(?MODULE, music, []),
    %Pid3 ! 'p',

    Pid3 = spawn(?MODULE, get_key_event, [Pid2]),
    %Pid3 ! {110},

		Wx = wx:new(),
		Frame = wxFrame:new(wx:null(), -1, "mp3player", [{size,{550,400}}]),
		Panel = wxPanel:new(Frame),
		Button = wxButton:new(Panel, 12, [{label,"play"}, {pos,{50,50}}]),
		Button2 = wxButton:new(Panel, 13, [{label,"pause"}, {pos,{140,50}}]),
		Button3 = wxButton:new(Panel, 14, [{label,"next"},{pos,{230,50}}]),
		Button4 = wxButton:new(Panel, 15, [{label,"prev"}, {pos,{320,50}}]),
		Button5 = wxButton:new(Panel, 16, [{label,"+"}, {pos,{50,150}}]),
		Button6 = wxButton:new(Panel, 17, [{label,"-"}, {pos,{185,150}}]),
		Button7 = wxButton:new(Panel, 18, [{label,"mute"}, {pos,{320,150}}]),
		wxButton:connect(Button, command_button_clicked, [{callback,
         fun(_,_) ->
						 Pid3 ! {play}
             end
         }]),
		wxButton:connect(Button2, command_button_clicked, [{callback,
        fun(_,_) ->
 					 Pid3 ! {pause}
            end
		     }]),
		 wxButton:connect(Button3, command_button_clicked, [{callback,
		         fun(_,_) ->
		  	Pid3 ! {next}
		             end
		 }]),
		 wxButton:connect(Button4, command_button_clicked, [{callback,
		         fun(_,_) ->
		  	Pid3 ! {prev}
		             end
		 }]),
		 wxButton:connect(Button5, command_button_clicked, [{callback,
		         fun(_,_) ->
		  	Pid3 ! {up}
		             end
		 }]),
		 wxButton:connect(Button6, command_button_clicked, [{callback,
		         fun(_,_) ->
		  	Pid3 ! {down}
		             end
		 }]),
		 wxButton:connect(Button7, command_button_clicked, [{callback,
		         fun(_,_) ->
		  	Pid3 ! {mute}
		             end
		 }]),
		 Choices=get_all_playlists(),
		 ListBox2 = wxListBox:new(Panel, 2, [{pos, {185,250}},{size, {-1,100}},
			{choices, Choices},
			{style, ?wxLB_SINGLE}]),

		wxListBox:setToolTip(ListBox2, "A wxListBox with single selection"),

		wxListBox:connect(ListBox2, command_listbox_doubleclicked, [{callback,
						fun(_, _) ->
			 Pid3 ! {change_playlist}
								end
		}]),
		wxListBox:connect(ListBox2, command_listbox_selected, [{callback,
						fun(_, _) ->
			 {_,[X]} = wxListBox:getSelections(ListBox2),
			 update_curr_playlist(X)
								end
		}]),

		wxFrame:show(Frame),




    ok.
