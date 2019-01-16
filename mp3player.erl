-module(mp3player).
-compile([export_all]).
-include_lib("wx/include/wx.hrl").

write() ->

    receive
        {play} ->
						%io:format("lol\n"),
            io:format("\nplaying ~p \nPLaylist: ~p\nVol: ~p Mute: ~p ~n", [get_curr_song(),get_curr_playlist(),get_vol(),is_mute()]),
            write();
        {pause} ->
            io:format("\npause ~p \nVol: ~p Mute: ~p ~n", [get_curr_song(),get_vol(),is_mute()]),
            write();
        {volume} ->
            io:format("\nVol: ~p Mute: ~p ~n", [get_vol(),is_mute()]),
            write()

    end.

end_of_song(Pid)->
	receive
		{next,false} -> Pid ! {next},
		end_of_song(Pid)
	end.

seconds(Pid,Paused)->
	receive
		{new}->
			Pid ! {new},
			seconds(Pid, false);
		{pause}->
			Pid ! {pause},
			seconds(Pid,true)
	after
		10000 ->
			Pid ! {next,Paused},
			seconds(Pid,Paused)
	end.



  get_event(WritePid) ->
		[{_, TimerPid}] = ets:lookup(pids, timerPid),
      receive
          {play} -> %112
              WritePid ! {play},
							TimerPid ! {new},
						  get_event(WritePid);
          {pause} -> %115
              WritePid ! {pause},
							TimerPid ! {pause},
              get_event(WritePid);
          {next} -> %110
              play_next_song(WritePid),
							TimerPid ! {new},
              get_event(WritePid);
					{prev} ->
	            play_prev_song(WritePid),
							TimerPid ! {new},
	            get_event(WritePid);
          {up} ->
              rise_vol(WritePid),
              get_event(WritePid);
          {down} ->
              lower_vol(WritePid),
              get_event(WritePid);
          {mute} ->
              update_mute(WritePid),
              get_event(WritePid);
					{change_playlist, Index} ->
							play_next_playlist(WritePid,Index),
							TimerPid ! {new},
							get_event(WritePid)

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
	Pid ! {play}.


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


init() ->
	ets:new(pids, [named_table, protected, set, {keypos, 1}]),
	WritePid = spawn(?MODULE, write, []),
	GetEventPid = spawn(?MODULE, get_event, [WritePid]),
	EndOdSongPid = spawn(?MODULE,end_of_song,[GetEventPid]),
	TimerPid = spawn(?MODULE,seconds,[EndOdSongPid,true]),
	ets:insert(pids, {timerPid, TimerPid}),
	run(GetEventPid).

button(Panel,GetEventPid) ->
	Songs = get_songs(),
	ListSongs = wxListBox:new(Panel, 2, [{pos, {215,250}},{size, {-1,100}},
		 {choices, Songs},
		 {style, ?wxLB_SINGLE}]),
 wxListBox:connect(ListSongs, command_listbox_doubleclicked, [{callback,
					fun(_, _) ->
						io:format("lol"),
		{_,[X]} = wxListBox:getSelections(ListSongs),
		update_curr_song(X),
		 GetEventPid ! {play},
		 timer:sleep(10)
							end
	}]).

run(GetEventPid) ->


		Wx = wx:new(),
		Frame = wxFrame:new(wx:null(), -1, "mp3player", [{size,{550,400}}]),
		Panel = wxPanel:new(Frame),
		PlayButton = wxButton:new(Panel, 12, [{label,"play"}, {pos,{50,50}}]),
		PauseButton = wxButton:new(Panel, 13, [{label,"pause"}, {pos,{140,50}}]),
		NextButton = wxButton:new(Panel, 14, [{label,"next"},{pos,{230,50}}]),
		PrevButton = wxButton:new(Panel, 15, [{label,"prev"}, {pos,{320,50}}]),
		UpButton = wxButton:new(Panel, 16, [{label,"+"}, {pos,{50,150}}]),
		DownButton = wxButton:new(Panel, 17, [{label,"-"}, {pos,{185,150}}]),
		MuteButton = wxButton:new(Panel, 18, [{label,"mute"}, {pos,{320,150}}]),
		ExitButton = wxButton:new(Panel, 19, [{label,"X"}, {pos,{320,50}}]),

		wxButton:connect(PlayButton, command_button_clicked, [{callback,
         fun(_,_) ->
						 GetEventPid ! {play}
             end
         }]),
		wxButton:connect(PauseButton, command_button_clicked, [{callback,
        fun(_,_) ->
 					 GetEventPid ! {pause}
            end
		     }]),
		 wxButton:connect(NextButton, command_button_clicked, [{callback,
		 fun(_,_) ->
				 GetEventPid ! {next}
				 end
		 }]),
		 wxButton:connect(PrevButton, command_button_clicked, [{callback,
		         fun(_,_) ->
		  	GetEventPid ! {prev}
		             end
		 }]),
		 wxButton:connect(UpButton, command_button_clicked, [{callback,
		         fun(_,_) ->
		  	GetEventPid ! {up}
		             end
		 }]),
		 wxButton:connect(DownButton, command_button_clicked, [{callback,
		         fun(_,_) ->
		  	GetEventPid ! {down}
		             end
		 }]),
		 wxButton:connect(MuteButton, command_button_clicked, [{callback,
		         fun(_,_) ->
		  	GetEventPid ! {mute}
		             end
		 }]),
		 wxButton:connect(ExitButton, command_button_clicked, [{callback,
		         fun(_,_) ->
							 [{_, TimerPid}] = ets:lookup(pids, timerPid),
				exit(TimerPid,reason),
		  	wxFrame:destroy(Frame)
		             end
		 }]),
		 Playlists=get_all_playlists(),
		 ListPlaylist = wxListBox:new(Panel, 2, [{pos, {50,250}},{size, {-1,100}},
			{choices, Playlists},
			{style, ?wxLB_SINGLE}]),

		wxListBox:setToolTip(ListPlaylist, "wszystkie playlisty:"),

		wxListBox:connect(ListPlaylist, command_listbox_doubleclicked, [{callback,
						fun(_, _) ->
			{_,[X]} = wxListBox:getSelections(ListPlaylist),
			 GetEventPid ! {change_playlist, X},
			 timer:sleep(10),
			 button(Panel,GetEventPid)
								end
		}]),

		wxFrame:show(Frame).
