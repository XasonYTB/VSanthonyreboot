package states;

import backend.WeekData;
import backend.Highscore;
import backend.Song;

import objects.HealthIcon;
import objects.MusicPlayer;

import options.GameplayChangersSubstate;
import substates.ResetScoreSubState;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.effects.FlxFlicker;
import flixel.util.FlxColor;
import flixel.math.FlxMath;
import flixel.util.FlxDestroyUtil;

import openfl.utils.Assets;
import haxe.Json;

// View mode enum
enum FreeplayView {
	CATEGORY_SELECT;
	SONG_SELECT;
}

class FreeplayState extends MusicBeatState
{
	// Category data
	var categories:Array<CategoryData> = [
		{name: 'Main', id: 'main', color: 0xFF3498DB, description: 'Main story songs'},
		{name: 'Extra', id: 'extra', color: 0xFF9B59B6, description: 'Bonus songs'},
		{name: 'Old', id: 'old', color: 0xFFE67E22, description: 'Songs from before the reboot'},
		{name: 'Secret', id: 'secret', color: 0xFFE74C3C, description: '???'}
	];

	var currentView:FreeplayView = CATEGORY_SELECT;
	public static var currentCategory:String = 'main';

	// Category selection UI
	var categoryItems:FlxTypedGroup<FlxText>;
	var catCurSelected:Int = 0;
	var categoryDescText:FlxText;

	// Song selection (original freeplay)
	var songs:Array<SongMetadata> = [];
	var selector:FlxText;
	private static var curSelected:Int = 0;
	var lerpSelected:Float = 0;
	var curDifficulty:Int = -1;
	private static var lastDifficultyName:String = Difficulty.getDefault();

	var scoreBG:FlxSprite;
	var scoreText:FlxText;
	var diffText:FlxText;
	var lerpScore:Int = 0;
	var lerpRating:Float = 0;
	var intendedScore:Int = 0;
	var intendedRating:Float = 0;

	private var grpSongs:FlxTypedGroup<Alphabet>;
	private var curPlaying:Bool = false;

	private var iconArray:Array<HealthIcon> = [];

	var bg:FlxSprite;
	var intendedColor:Int;

	var missingTextBG:FlxSprite;
	var missingText:FlxText;

	var bottomString:String;
	var bottomText:FlxText;
	var bottomBG:FlxSprite;

	var player:MusicPlayer;

	// Title text
	var titleText:FlxText;

	// Particles
	var particles:FlxTypedGroup<FloatingParticle>;
	var particleTimer:Float = 0;

	override function create()
	{
		persistentUpdate = true;
		PlayState.isStoryMode = false;
		WeekData.reloadWeekFiles(false);

		#if DISCORD_ALLOWED
		DiscordClient.changePresence("VS Anthony REBOOTED", "Selecting Category");
		#end

		// Background
		bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFF2C3E50);
		bg.antialiasing = ClientPrefs.data.antialiasing;
		add(bg);

		// Particles
		particles = new FlxTypedGroup<FloatingParticle>();
		add(particles);

		for (i in 0...20)
			spawnParticle(true);

		// Title
		titleText = new FlxText(0, 30, FlxG.width, "SELECT CATEGORY", 42);
		titleText.setFormat(Paths.font("vcr.ttf"), 42, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		titleText.borderSize = 3;
		add(titleText);

		// Create category selection UI
		createCategoryUI();

		// Create song selection UI (hidden initially)
		createSongUI();

		// Set initial view
		setCategoryView();

		super.create();
	}

	function createCategoryUI():Void
	{
		categoryItems = new FlxTypedGroup<FlxText>();
		add(categoryItems);

		var startY:Float = 130;
		for (i in 0...categories.length)
		{
			var catText:FlxText = new FlxText(0, startY + (i * 90), FlxG.width, categories[i].name, 52);
			catText.setFormat(Paths.font("vcr.ttf"), 52, categories[i].color, CENTER, FlxTextBorderStyle.SHADOW, FlxColor.BLACK);
			catText.borderSize = 3;
			catText.ID = i;
			categoryItems.add(catText);
		}

		// Description
		categoryDescText = new FlxText(0, FlxG.height - 120, FlxG.width, '', 22);
		categoryDescText.setFormat(Paths.font("vcr.ttf"), 22, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(categoryDescText);
	}

	function createSongUI():Void
	{
		grpSongs = new FlxTypedGroup<Alphabet>();
		add(grpSongs);

		scoreText = new FlxText(FlxG.width * 0.7, 5, 0, "", 32);
		scoreText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, RIGHT);

		scoreBG = new FlxSprite(scoreText.x - 6, 0).makeGraphic(1, 66, 0xFF000000);
		scoreBG.alpha = 0.6;
		add(scoreBG);

		diffText = new FlxText(scoreText.x, scoreText.y + 36, 0, "", 24);
		diffText.font = scoreText.font;
		add(diffText);

		add(scoreText);

		missingTextBG = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		missingTextBG.alpha = 0.6;
		missingTextBG.visible = false;
		add(missingTextBG);

		missingText = new FlxText(50, 0, FlxG.width - 100, '', 24);
		missingText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		missingText.scrollFactor.set();
		missingText.visible = false;
		add(missingText);

		bottomBG = new FlxSprite(0, FlxG.height - 26).makeGraphic(FlxG.width, 26, 0xFF000000);
		bottomBG.alpha = 0.6;
		add(bottomBG);

		var leText:String = "SPACE: Preview | CTRL: Gameplay Changers | RESET: Reset Score | BACKSPACE: Back";
		bottomString = leText;
		bottomText = new FlxText(bottomBG.x, bottomBG.y + 4, FlxG.width, leText, 16);
		bottomText.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, CENTER);
		bottomText.scrollFactor.set();
		add(bottomText);

		player = new MusicPlayer(this);
		add(player);
	}

	function setCategoryView():Void
	{
		currentView = CATEGORY_SELECT;

		titleText.text = "SELECT CATEGORY";
		titleText.visible = true;

		// Show category UI
		categoryItems.visible = true;
		categoryDescText.visible = true;
		changeCategorySelection();

		// Hide song UI
		grpSongs.visible = false;
		for (icon in iconArray)
			icon.visible = false;
		scoreText.visible = false;
		scoreBG.visible = false;
		diffText.visible = false;
		bottomBG.visible = false;
		bottomText.visible = false;
		player.visible = false;

		#if DISCORD_ALLOWED
		DiscordClient.changePresence("VS Anthony REBOOTED", "Selecting Category");
		#end
	}

	function setSongView():Void
	{
		currentView = SONG_SELECT;

		titleText.text = categories[catCurSelected].name.toUpperCase() + " SONGS";
		titleText.visible = true;

		// Hide category UI
		categoryItems.visible = false;
		categoryDescText.visible = false;

		// Load songs for selected category
		loadSongsForCategory(currentCategory);

		// Show song UI
		grpSongs.visible = true;
		scoreText.visible = true;
		scoreBG.visible = true;
		diffText.visible = true;
		bottomBG.visible = true;
		bottomText.visible = true;
		player.visible = true;

		if (songs.length > 0)
		{
			curSelected = 0;
			lerpSelected = 0;
			changeSelection();
		}

		#if DISCORD_ALLOWED
		DiscordClient.changePresence("VS Anthony REBOOTED", "Browsing " + categories[catCurSelected].name + " Songs");
		#end
	}

	function loadSongsForCategory(category:String):Void
	{
		// Clear existing songs
		songs = [];
		grpSongs.clear();
		for (icon in iconArray)
		{
			icon.destroy();
		}
		iconArray = [];

		// Load weeks and filter by category
		// You'll need to set up your weeks with a "category" field in the week JSON
		// Or use folder naming convention like: week1_main, week2_extra, etc.

		for (i in 0...WeekData.weeksList.length)
		{
			if (weekIsLocked(WeekData.weeksList[i]))
				continue;

			var leWeek:WeekData = WeekData.weeksLoaded.get(WeekData.weeksList[i]);

			// Check if this week belongs to the selected category
			// Option 1: Check week name prefix (e.g., "main_week1", "extra_week1")
			// Option 2: Add a custom field in week JSON
			var weekCategory:String = getWeekCategory(WeekData.weeksList[i], leWeek);

			if (weekCategory != category)
				continue;

			WeekData.setDirectoryFromWeek(leWeek);
			for (song in leWeek.songs)
			{
				var colors:Array<Int> = song[2];
				if (colors == null || colors.length < 3)
					colors = [146, 113, 253];
				addSong(song[0], i, song[1], FlxColor.fromRGB(colors[0], colors[1], colors[2]));
			}
		}

		Mods.loadTopMod();

		// Create song UI elements
		for (i in 0...songs.length)
		{
			var songText:Alphabet = new Alphabet(90, 320, songs[i].songName, true);
			songText.targetY = i;
			grpSongs.add(songText);

			songText.scaleX = Math.min(1, 980 / songText.width);
			songText.snapToPosition();

			Mods.currentModDirectory = songs[i].folder;
			var icon:HealthIcon = new HealthIcon(songs[i].songCharacter);
			icon.sprTracker = songText;

			songText.visible = songText.active = songText.isMenuItem = false;
			icon.visible = icon.active = false;

			iconArray.push(icon);
			add(icon);
		}

		WeekData.setDirectoryFromWeek();

		// Handle empty category
		if (songs.length == 0)
		{
			var noSongsText:Alphabet = new Alphabet(0, 300, "No songs available", true);
			noSongsText.screenCenter(X);
			grpSongs.add(noSongsText);
		}

		// Setup difficulty
		if (songs.length > 0)
		{
			bg.color = songs[0].color;
			intendedColor = bg.color;
			curDifficulty = Math.round(Math.max(0, Difficulty.defaultList.indexOf(lastDifficultyName)));
		}
	}

	// Determine which category a week belongs to
	// Customize this based on how you organize your weeks
	function getWeekCategory(weekName:String, weekData:WeekData):String
	{
		// Method 1: Check week name prefix
		if (weekName.indexOf('main_') == 0 || weekName.indexOf('Main_') == 0)
			return 'main';
		if (weekName.indexOf('extra_') == 0 || weekName.indexOf('Extra_') == 0)
			return 'extra';
		if (weekName.indexOf('old_') == 0 || weekName.indexOf('Old_') == 0)
			return 'old';
		if (weekName.indexOf('secret_') == 0 || weekName.indexOf('Secret_') == 0)
			return 'secret';

		// Method 2: Check for custom field in week data (if you add one)
		// if (Reflect.hasField(weekData, 'category'))
		//     return Reflect.field(weekData, 'category');

		// Default to main
		return 'main';
	}

	function spawnParticle(randomY:Bool = false):Void
	{
		var particle = new FloatingParticle();
		particle.x = FlxG.random.float(20, FlxG.width - 20);
		particle.y = randomY ? FlxG.random.float(0, FlxG.height) : FlxG.height + 10;
		particles.add(particle);
	}

	override function closeSubState()
	{
		changeSelection(0, false);
		persistentUpdate = true;
		super.closeSubState();
	}

	public function addSong(songName:String, weekNum:Int, songCharacter:String, color:Int)
	{
		songs.push(new SongMetadata(songName, weekNum, songCharacter, color));
	}

	function weekIsLocked(name:String):Bool
	{
		var leWeek:WeekData = WeekData.weeksLoaded.get(name);
		return (!leWeek.startUnlocked && leWeek.weekBefore.length > 0 && (!StoryMenuState.weekCompleted.exists(leWeek.weekBefore) || !StoryMenuState.weekCompleted.get(leWeek.weekBefore)));
	}

	// Check if secret category is unlocked
	function isSecretUnlocked():Bool
	{
		// Customize your unlock conditions here!
		// Examples:
		// - Check if certain songs are beaten
		// - Check for achievement
		// - Check save data flag

		// For now, check if a save flag exists
		if (FlxG.save.data.secretUnlocked != null && FlxG.save.data.secretUnlocked == true)
			return true;

		// Or check if all main songs are completed
		// return checkAllMainSongsCompleted();

		return false; // Locked by default
	}

	// Call this to unlock secret category (from gameplay, achievements, etc.)
	public static function unlockSecret():Void
	{
		FlxG.save.data.secretUnlocked = true;
		FlxG.save.flush();
	}

	var instPlaying:Int = -1;
	public static var vocals:FlxSound = null;
	public static var opponentVocals:FlxSound = null;
	var holdTime:Float = 0;
	var stopMusicPlay:Bool = false;

	override function update(elapsed:Float)
	{
		// Particle management
		particleTimer += elapsed;
		if (particleTimer >= 0.15)
		{
			particleTimer = 0;
			spawnParticle();
		}

		particles.forEachAlive(function(p:FloatingParticle)
		{
			if (p.y < -20 || p.x < -20 || p.x > FlxG.width + 20)
			{
				p.kill();
				particles.remove(p, true);
				p.destroy();
			}
		});

		if (FlxG.sound.music.volume < 0.7)
			FlxG.sound.music.volume += 0.5 * elapsed;

		// Handle input based on current view
		switch (currentView)
		{
			case CATEGORY_SELECT:
				updateCategorySelect(elapsed);
			case SONG_SELECT:
				updateSongSelect(elapsed);
		}

		super.update(elapsed);
	}

	function updateCategorySelect(elapsed:Float):Void
	{
		// Lerp background color
		var targetColor:Int = categories[catCurSelected].color;
		bg.color = FlxColor.interpolate(bg.color, Std.int(targetColor * 0.4 + 0xFF1A1A2E), 0.08);

		if (controls.UI_UP_P)
			changeCategorySelection(-1);
		if (controls.UI_DOWN_P)
			changeCategorySelection(1);

		if (controls.BACK)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			MusicBeatState.switchState(new MainMenuState());
		}

		if (controls.ACCEPT)
		{
			selectCategory();
		}
	}

	function changeCategorySelection(change:Int = 0):Void
	{
		catCurSelected = FlxMath.wrap(catCurSelected + change, 0, categories.length - 1);

		if (change != 0)
			FlxG.sound.play(Paths.sound('scrollMenu'));

		for (item in categoryItems)
		{
			if (item.ID == catCurSelected)
			{
				item.scale.set(1.2, 1.2);
				item.alpha = 1;

				// Check if secret and locked
				if (categories[catCurSelected].id == 'secret' && !isSecretUnlocked())
				{
					categoryDescText.text = "??? (LOCKED)";
					categoryDescText.color = 0xFFE74C3C;
				}
				else
				{
					categoryDescText.text = categories[catCurSelected].description;
					categoryDescText.color = FlxColor.WHITE;
				}
			}
			else
			{
				item.scale.set(1, 1);
				item.alpha = 0.5;
			}
		}
	}

	function selectCategory():Void
	{
		var selectedCat = categories[catCurSelected];

		// Check if secret is locked
		if (selectedCat.id == 'secret' && !isSecretUnlocked())
		{
			FlxG.sound.play(Paths.sound('cancelMenu'));
			var item = categoryItems.members[catCurSelected];
			FlxTween.cancelTweensOf(item);
			FlxTween.shake(item, 0.02, 0.3);
			return;
		}

		FlxG.sound.play(Paths.sound('confirmMenu'));
		currentCategory = selectedCat.id;

		// Transition to song view
		var selectedItem:FlxText = categoryItems.members[catCurSelected];
		FlxFlicker.flicker(selectedItem, 0.5, 0.06, false, false, function(flick:FlxFlicker)
		{
			setSongView();
		});
	}

	function updateSongSelect(elapsed:Float):Void
	{
		if (songs.length == 0)
		{
			if (controls.BACK)
			{
				FlxG.sound.play(Paths.sound('cancelMenu'));
				setCategoryView();
			}
			return;
		}

		lerpScore = Math.floor(FlxMath.lerp(intendedScore, lerpScore, Math.exp(-elapsed * 24)));
		lerpRating = FlxMath.lerp(intendedRating, lerpRating, Math.exp(-elapsed * 12));

		if (Math.abs(lerpScore - intendedScore) <= 10)
			lerpScore = intendedScore;
		if (Math.abs(lerpRating - intendedRating) <= 0.01)
			lerpRating = intendedRating;

		var ratingSplit:Array<String> = Std.string(CoolUtil.floorDecimal(lerpRating * 100, 2)).split('.');
		if (ratingSplit.length < 2)
			ratingSplit.push('');
		while (ratingSplit[1].length < 2)
			ratingSplit[1] += '0';

		var shiftMult:Int = 1;
		if (FlxG.keys.pressed.SHIFT)
			shiftMult = 3;

		if (!player.playingMusic)
		{
			scoreText.text = 'PERSONAL BEST: ${lerpScore} (${ratingSplit.join('.')}%)';
			positionHighscore();

			if (songs.length > 1)
			{
				if (FlxG.keys.justPressed.HOME)
				{
					curSelected = 0;
					changeSelection();
					holdTime = 0;
				}
				else if (FlxG.keys.justPressed.END)
				{
					curSelected = songs.length - 1;
					changeSelection();
					holdTime = 0;
				}
				if (controls.UI_UP_P)
				{
					changeSelection(-shiftMult);
					holdTime = 0;
				}
				if (controls.UI_DOWN_P)
				{
					changeSelection(shiftMult);
					holdTime = 0;
				}

				if (controls.UI_DOWN || controls.UI_UP)
				{
					var checkLastHold:Int = Math.floor((holdTime - 0.5) * 10);
					holdTime += elapsed;
					var checkNewHold:Int = Math.floor((holdTime - 0.5) * 10);

					if (holdTime > 0.5 && checkNewHold - checkLastHold > 0)
						changeSelection((checkNewHold - checkLastHold) * (controls.UI_UP ? -shiftMult : shiftMult));
				}

				if (FlxG.mouse.wheel != 0)
				{
					FlxG.sound.play(Paths.sound('scrollMenu'), 0.2);
					changeSelection(-shiftMult * FlxG.mouse.wheel, false);
				}
			}

			if (controls.UI_LEFT_P)
			{
				changeDiff(-1);
				_updateSongLastDifficulty();
			}
			else if (controls.UI_RIGHT_P)
			{
				changeDiff(1);
				_updateSongLastDifficulty();
			}
		}

		if (controls.BACK)
		{
			if (player.playingMusic)
			{
				FlxG.sound.music.stop();
				destroyFreeplayVocals();
				FlxG.sound.music.volume = 0;
				instPlaying = -1;

				player.playingMusic = false;
				player.switchPlayMusic();

				FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);
				FlxTween.tween(FlxG.sound.music, {volume: 1}, 1);
			}
			else
			{
				FlxG.sound.play(Paths.sound('cancelMenu'));
				setCategoryView();
			}
		}

		if (FlxG.keys.justPressed.CONTROL && !player.playingMusic)
		{
			persistentUpdate = false;
			openSubState(new GameplayChangersSubstate());
		}
		else if (FlxG.keys.justPressed.SPACE)
		{
			handleSpacePress();
		}
		else if (controls.ACCEPT && !player.playingMusic)
		{
			playSong();
		}
		else if (controls.RESET && !player.playingMusic)
		{
			persistentUpdate = false;
			openSubState(new ResetScoreSubState(songs[curSelected].songName, curDifficulty, songs[curSelected].songCharacter));
			FlxG.sound.play(Paths.sound('scrollMenu'));
		}

		updateTexts(elapsed);
	}

	function handleSpacePress():Void
	{
		if (instPlaying != curSelected && !player.playingMusic)
		{
			destroyFreeplayVocals();
			FlxG.sound.music.volume = 0;

			Mods.currentModDirectory = songs[curSelected].folder;
			var poop:String = Highscore.formatSong(songs[curSelected].songName.toLowerCase(), curDifficulty);
			Song.loadFromJson(poop, songs[curSelected].songName.toLowerCase());
			if (PlayState.SONG.needsVoices)
			{
				vocals = new FlxSound();
				try
				{
					var playerVocals:String = getVocalFromCharacter(PlayState.SONG.player1);
					var loadedVocals = Paths.voices(PlayState.SONG.song, (playerVocals != null && playerVocals.length > 0) ? playerVocals : 'Player');
					if (loadedVocals == null)
						loadedVocals = Paths.voices(PlayState.SONG.song);

					if (loadedVocals != null && loadedVocals.length > 0)
					{
						vocals.loadEmbedded(loadedVocals);
						FlxG.sound.list.add(vocals);
						vocals.persist = vocals.looped = true;
						vocals.volume = 0.8;
						vocals.play();
						vocals.pause();
					}
					else
						vocals = FlxDestroyUtil.destroy(vocals);
				}
				catch (e:Dynamic)
				{
					vocals = FlxDestroyUtil.destroy(vocals);
				}

				opponentVocals = new FlxSound();
				try
				{
					var oppVocals:String = getVocalFromCharacter(PlayState.SONG.player2);
					var loadedVocals = Paths.voices(PlayState.SONG.song, (oppVocals != null && oppVocals.length > 0) ? oppVocals : 'Opponent');

					if (loadedVocals != null && loadedVocals.length > 0)
					{
						opponentVocals.loadEmbedded(loadedVocals);
						FlxG.sound.list.add(opponentVocals);
						opponentVocals.persist = opponentVocals.looped = true;
						opponentVocals.volume = 0.8;
						opponentVocals.play();
						opponentVocals.pause();
					}
					else
						opponentVocals = FlxDestroyUtil.destroy(opponentVocals);
				}
				catch (e:Dynamic)
				{
					opponentVocals = FlxDestroyUtil.destroy(opponentVocals);
				}
			}

			FlxG.sound.playMusic(Paths.inst(PlayState.SONG.song), 0.8);
			FlxG.sound.music.pause();
			instPlaying = curSelected;

			player.playingMusic = true;
			player.curTime = 0;
			player.switchPlayMusic();
			player.pauseOrResume(true);
		}
		else if (instPlaying == curSelected && player.playingMusic)
		{
			player.pauseOrResume(!player.playing);
		}
	}

	function playSong():Void
	{
		persistentUpdate = false;
		var songLowercase:String = Paths.formatToSongPath(songs[curSelected].songName);
		var poop:String = Highscore.formatSong(songLowercase, curDifficulty);

		try
		{
			Song.loadFromJson(poop, songLowercase);
			PlayState.isStoryMode = false;
			PlayState.storyDifficulty = curDifficulty;

			trace('CURRENT WEEK: ' + WeekData.getWeekFileName());
		}
		catch (e:haxe.Exception)
		{
			trace('ERROR! ${e.message}');

			var errorStr:String = e.message;
			if (errorStr.contains('There is no TEXT asset with an ID of'))
				errorStr = 'Missing file: ' + errorStr.substring(errorStr.indexOf(songLowercase), errorStr.length - 1);
			else
				errorStr += '\n\n' + e.stack;

			missingText.text = 'ERROR WHILE LOADING CHART:\n$errorStr';
			missingText.screenCenter(Y);
			missingText.visible = true;
			missingTextBG.visible = true;
			FlxG.sound.play(Paths.sound('cancelMenu'));
			return;
		}

		@:privateAccess
		if (PlayState._lastLoadedModDirectory != Mods.currentModDirectory)
		{
			trace('CHANGED MOD DIRECTORY, RELOADING STUFF');
			Paths.freeGraphicsFromMemory();
		}
		LoadingState.prepareToSong();
		LoadingState.loadAndSwitchState(new PlayState());
		#if !SHOW_LOADING_SCREEN FlxG.sound.music.stop(); #end
		stopMusicPlay = true;

		destroyFreeplayVocals();
		#if (MODS_ALLOWED && DISCORD_ALLOWED)
		DiscordClient.loadModRPC();
		#end
	}

	function getVocalFromCharacter(char:String)
	{
		try
		{
			var path:String = Paths.getPath('characters/$char.json', TEXT);
			#if MODS_ALLOWED
			var character:Dynamic = Json.parse(File.getContent(path));
			#else
			var character:Dynamic = Json.parse(Assets.getText(path));
			#end
			return character.vocals_file;
		}
		catch (e:Dynamic) {}
		return null;
	}

	public static function destroyFreeplayVocals()
	{
		if (vocals != null)
			vocals.stop();
		vocals = FlxDestroyUtil.destroy(vocals);

		if (opponentVocals != null)
			opponentVocals.stop();
		opponentVocals = FlxDestroyUtil.destroy(opponentVocals);
	}

	function changeDiff(change:Int = 0)
	{
		if (player.playingMusic)
			return;

		curDifficulty = FlxMath.wrap(curDifficulty + change, 0, Difficulty.list.length - 1);
		#if !switch
		intendedScore = Highscore.getScore(songs[curSelected].songName, curDifficulty);
		intendedRating = Highscore.getRating(songs[curSelected].songName, curDifficulty);
		#end

		lastDifficultyName = Difficulty.getString(curDifficulty, false);
		var displayDiff:String = Difficulty.getString(curDifficulty);
		if (Difficulty.list.length > 1)
			diffText.text = '< ' + displayDiff.toUpperCase() + ' >';
		else
			diffText.text = displayDiff.toUpperCase();

		positionHighscore();
		missingText.visible = false;
		missingTextBG.visible = false;
	}

	function changeSelection(change:Int = 0, playSound:Bool = true)
	{
		if (player.playingMusic)
			return;

		curSelected = FlxMath.wrap(curSelected + change, 0, songs.length - 1);
		_updateSongLastDifficulty();
		if (playSound)
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

		var newColor:Int = songs[curSelected].color;
		if (newColor != intendedColor)
		{
			intendedColor = newColor;
			FlxTween.cancelTweensOf(bg);
			FlxTween.color(bg, 1, bg.color, intendedColor);
		}

		for (num => item in grpSongs.members)
		{
			if (num >= iconArray.length)
				continue;
			var icon:HealthIcon = iconArray[num];
			item.alpha = 0.6;
			icon.alpha = 0.6;
			if (item.targetY == curSelected)
			{
				item.alpha = 1;
				icon.alpha = 1;
			}
		}

		Mods.currentModDirectory = songs[curSelected].folder;
		PlayState.storyWeek = songs[curSelected].week;
		Difficulty.loadFromWeek();

		var savedDiff:String = songs[curSelected].lastDifficulty;
		var lastDiff:Int = Difficulty.list.indexOf(lastDifficultyName);
		if (savedDiff != null && !Difficulty.list.contains(savedDiff) && Difficulty.list.contains(savedDiff))
			curDifficulty = Math.round(Math.max(0, Difficulty.list.indexOf(savedDiff)));
		else if (lastDiff > -1)
			curDifficulty = lastDiff;
		else if (Difficulty.list.contains(Difficulty.getDefault()))
			curDifficulty = Math.round(Math.max(0, Difficulty.defaultList.indexOf(Difficulty.getDefault())));
		else
			curDifficulty = 0;

		changeDiff();
		_updateSongLastDifficulty();
	}

	inline private function _updateSongLastDifficulty()
	{
		if (songs.length > 0)
			songs[curSelected].lastDifficulty = Difficulty.getString(curDifficulty, false);
	}

	private function positionHighscore()
	{
		scoreText.x = FlxG.width - scoreText.width - 6;
		scoreBG.scale.x = FlxG.width - scoreText.x + 6;
		scoreBG.x = FlxG.width - (scoreBG.scale.x / 2);
		diffText.x = Std.int(scoreBG.x + (scoreBG.width / 2));
		diffText.x -= diffText.width / 2;
	}

	var _drawDistance:Int = 4;
	var _lastVisibles:Array<Int> = [];

	public function updateTexts(elapsed:Float = 0.0)
	{
		lerpSelected = FlxMath.lerp(curSelected, lerpSelected, Math.exp(-elapsed * 9.6));
		for (i in _lastVisibles)
		{
			if (i < grpSongs.members.length)
			{
				grpSongs.members[i].visible = grpSongs.members[i].active = false;
			}
			if (i < iconArray.length)
			{
				iconArray[i].visible = iconArray[i].active = false;
			}
		}
		_lastVisibles = [];

		var min:Int = Math.round(Math.max(0, Math.min(songs.length, lerpSelected - _drawDistance)));
		var max:Int = Math.round(Math.max(0, Math.min(songs.length, lerpSelected + _drawDistance)));
		for (i in min...max)
		{
			if (i >= grpSongs.members.length)
				continue;
			var item:Alphabet = grpSongs.members[i];
			item.visible = item.active = true;
			item.x = ((item.targetY - lerpSelected) * item.distancePerItem.x) + item.startPosition.x;
			item.y = ((item.targetY - lerpSelected) * 1.3 * item.distancePerItem.y) + item.startPosition.y;

			if (i < iconArray.length)
			{
				var icon:HealthIcon = iconArray[i];
				icon.visible = icon.active = true;
			}
			_lastVisibles.push(i);
		}
	}

	override function destroy():Void
	{
		super.destroy();

		FlxG.autoPause = ClientPrefs.data.autoPause;
		if (!FlxG.sound.music.playing && !stopMusicPlay)
			FlxG.sound.playMusic(Paths.music('freakyMenu'));
	}
}

class SongMetadata
{
	public var songName:String = "";
	public var week:Int = 0;
	public var songCharacter:String = "";
	public var color:Int = -7179779;
	public var folder:String = "";
	public var lastDifficulty:String = null;

	public function new(song:String, week:Int, songCharacter:String, color:Int)
	{
		this.songName = song;
		this.week = week;
		this.songCharacter = songCharacter;
		this.color = color;
		this.folder = Mods.currentModDirectory;
		if (this.folder == null)
			this.folder = '';
	}
}

typedef CategoryData = {
	var name:String;
	var id:String;
	var color:Int;
	var description:String;
}
