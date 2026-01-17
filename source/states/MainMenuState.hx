package states;

import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.FlxG;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.effects.FlxFlicker;
import flixel.util.FlxColor;
import flixel.math.FlxMath;
import lime.app.Application;
import options.OptionsState;

class MainMenuState extends MusicBeatState
{
	public static var engineVersion:String = '1.0.0';
	public static var curSelected:Int = 0;

	var menuItems:FlxTypedGroup<FlxText>;
	var optionShit:Array<String> = ['Songs', 'Options'];

	// Background elements
	var bgGray:FlxSprite;
	var bgGreen:FlxSprite;

	// Floating particles
	var particles:FlxTypedGroup<FloatingParticle>;
	var particleTimer:Float = 0;

	// Character display
	var characterSprite:FlxSprite;

	var selectedSomethin:Bool = false;

	override function create()
	{
		super.create();

		#if MODS_ALLOWED
		Mods.pushGlobalMods();
		#end
		Mods.loadTopMod();

		#if DISCORD_ALLOWED
		DiscordClient.changePresence("VS Anthony REBOOTED", "In the Menus");
		#end

		persistentUpdate = persistentDraw = true;

		// Create the diagonal split background
		createBackground();

		// Create floating particles
		particles = new FlxTypedGroup<FloatingParticle>();
		add(particles);

		// Spawn initial particles
		for (i in 0...25)
		{
			spawnParticle(true);
		}

		// Create menu items
		menuItems = new FlxTypedGroup<FlxText>();
		add(menuItems);

		for (i in 0...optionShit.length)
		{
			var menuText:FlxText = new FlxText(60, 120 + (i * 140), 0, optionShit[i], 72);
			menuText.setFormat(Paths.font("vcr.ttf"), 72, FlxColor.WHITE, LEFT, FlxTextBorderStyle.SHADOW, FlxColor.BLACK);
			menuText.borderSize = 4;
			menuText.antialiasing = ClientPrefs.data.antialiasing;
			menuText.ID = i;
			menuItems.add(menuText);
		}

		// Character sprite on the right side
		characterSprite = new FlxSprite(FlxG.width * 0.55, FlxG.height * 0.2);
		// Try to load character image, fallback to placeholder if not found
		try {
			characterSprite.loadGraphic(Paths.image('mainmenu/character_songs'));
		} catch (e:Dynamic) {
			characterSprite.makeGraphic(350, 450, FlxColor.TRANSPARENT);
		}
		characterSprite.antialiasing = ClientPrefs.data.antialiasing;
		add(characterSprite);

		// Version text
		var versionText:FlxText = new FlxText(12, FlxG.height - 24, 0, "VS Anthony REBOOTED v" + engineVersion, 16);
		versionText.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		versionText.scrollFactor.set();
		add(versionText);

		changeSelection();
	}

	function createBackground():Void
	{
		// Create base gray background
		bgGray = new FlxSprite(0, 0).makeGraphic(FlxG.width, FlxG.height, 0xFF4A4A4A);
		bgGray.scrollFactor.set();
		add(bgGray);

		// Draw the diagonal split directly onto the background
		// This creates gray on left, green on right with diagonal divide
		for (y in 0...FlxG.height)
		{
			for (x in 0...FlxG.width)
			{
				// Diagonal line: starts at roughly 35% width at top, goes to 55% at bottom
				var splitX:Float = (y / FlxG.height) * (FlxG.width * 0.25) + (FlxG.width * 0.32);

				if (x > splitX)
				{
					bgGray.pixels.setPixel32(x, y, 0xFF2ECC71); // Green
				}
			}
		}
	}

	function spawnParticle(randomY:Bool = false):Void
	{
		var particle:FloatingParticle = new FloatingParticle();
		// Spawn particles mostly on the green (right) side
		particle.x = FlxG.random.float(FlxG.width * 0.35, FlxG.width - 20);
		particle.y = randomY ? FlxG.random.float(0, FlxG.height) : FlxG.height + 10;
		particles.add(particle);
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		// Update particles
		particleTimer += elapsed;
		if (particleTimer >= 0.12)
		{
			particleTimer = 0;
			spawnParticle();
		}

		// Remove off-screen particles
		particles.forEachAlive(function(p:FloatingParticle)
		{
			if (p.y < -20 || p.x < -20 || p.x > FlxG.width + 20)
			{
				p.kill();
				particles.remove(p, true);
				p.destroy();
			}
		});

		if (!selectedSomethin)
		{
			if (controls.UI_UP_P)
				changeSelection(-1);
			if (controls.UI_DOWN_P)
				changeSelection(1);

			if (controls.BACK)
			{
				selectedSomethin = true;
				FlxG.sound.play(Paths.sound('cancelMenu'));
				MusicBeatState.switchState(new TitleState());
			}

			if (controls.ACCEPT)
			{
				selectOption();
			}

			#if desktop
			if (controls.justPressed('debug_1'))
			{
				selectedSomethin = true;
				MusicBeatState.switchState(new states.editors.MasterEditorMenu());
			}
			#end
		}
	}

	function changeSelection(change:Int = 0):Void
	{
		curSelected = FlxMath.wrap(curSelected + change, 0, optionShit.length - 1);

		if (change != 0)
			FlxG.sound.play(Paths.sound('scrollMenu'));

		// Update menu item colors and styling
		for (item in menuItems)
		{
			if (item.ID == curSelected)
			{
				// Selected item styling
				if (optionShit[curSelected] == 'Songs')
				{
					item.color = 0xFFFFCC00; // Yellow/Gold for Songs
				}
				else
				{
					item.color = 0xFF2ECC71; // Green for Options
				}
				item.scale.set(1.15, 1.15);
			}
			else
			{
				// Unselected styling - slightly darker/muted
				if (optionShit[item.ID] == 'Songs')
				{
					item.color = 0xFFB8960F; // Muted yellow
				}
				else
				{
					item.color = 0xFF1E8449; // Muted green
				}
				item.scale.set(1, 1);
			}
		}

		// Update character sprite based on selection
		updateCharacter();
	}

	function updateCharacter():Void
	{
		// Change character image based on current selection
		// Add your character images to: assets/images/mainmenu/
		// character_songs.png and character_options.png

		var imagePath:String = 'mainmenu/character_' + optionShit[curSelected].toLowerCase();

		try {
			characterSprite.loadGraphic(Paths.image(imagePath));
		} catch (e:Dynamic) {
			// If image doesn't exist, just do a visual tween
		}

		// Tween effect for visual feedback
		FlxTween.cancelTweensOf(characterSprite);
		characterSprite.alpha = 0.7;
		FlxTween.tween(characterSprite, {alpha: 1}, 0.3, {ease: FlxEase.quadOut});
	}

	function selectOption():Void
	{
		selectedSomethin = true;
		FlxG.sound.play(Paths.sound('confirmMenu'));

		var selectedItem:FlxText = null;
		for (item in menuItems)
		{
			if (item.ID == curSelected)
			{
				selectedItem = item;
			}
			else
			{
				FlxTween.tween(item, {alpha: 0}, 0.4, {ease: FlxEase.quadOut});
			}
		}

		// Fade out character too
		FlxTween.tween(characterSprite, {alpha: 0}, 0.4, {ease: FlxEase.quadOut});

		FlxFlicker.flicker(selectedItem, 1, 0.06, false, false, function(flick:FlxFlicker)
		{
			switch (optionShit[curSelected])
			{
				case 'Songs':
					MusicBeatState.switchState(new FreeplayState());
				case 'Options':
					MusicBeatState.switchState(new OptionsState());
					OptionsState.onPlayState = false;
					if (PlayState.SONG != null)
					{
						PlayState.SONG.arrowSkin = null;
						PlayState.SONG.splashSkin = null;
						PlayState.stageUI = 'normal';
					}
			}
		});
	}
}

// Floating particle class for the dot stars
class FloatingParticle extends FlxSprite
{
	var velocityX:Float;
	var velocityY:Float;

	public function new()
	{
		super();

		// Create a small yellow circle/dot
		makeGraphic(10, 10, 0xFFE8D44D);

		// Random velocity - up-left or up-right
		var goLeft:Bool = FlxG.random.bool();
		velocityX = goLeft ? FlxG.random.float(-40, -80) : FlxG.random.float(40, 80);
		velocityY = FlxG.random.float(-100, -160); // Always going up

		// Random size variation
		var randomScale:Float = FlxG.random.float(0.4, 1.0);
		scale.set(randomScale, randomScale);

		// Slight transparency variation
		alpha = FlxG.random.float(0.7, 1.0);

		antialiasing = ClientPrefs.data.antialiasing;
	}

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);

		x += velocityX * elapsed;
		y += velocityY * elapsed;

		// Slight random wobble for more organic movement
		velocityX += FlxG.random.float(-10, 10) * elapsed;
	}
}
