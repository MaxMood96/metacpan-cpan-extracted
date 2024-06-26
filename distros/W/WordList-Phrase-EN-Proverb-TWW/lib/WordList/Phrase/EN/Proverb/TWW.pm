package WordList::Phrase::EN::Proverb::TWW;

our $DATE = '2016-01-13'; # DATE
our $VERSION = '0.03'; # VERSION

use WordList;
our @ISA = qw(WordList);

our %STATS = ("avg_word_len",37.4152542372881,"num_words",472,"num_words_contains_unicode",0,"longest_word_len",97,"shortest_word_len",13,"num_words_contains_whitespace",472,"num_words_contains_nonword_chars",472); # STATS

1;
# ABSTRACT: Proverb phrases from Tom Wills




=pod

=encoding UTF-8

=head1 NAME

WordList::Phrase::EN::Proverb::TWW - Proverb phrases from Tom Wills

=head1 VERSION

This document describes version 0.03 of WordList::Phrase::EN::Proverb::TWW (from Perl distribution WordList-Phrase-EN-Proverb-TWW), released on 2016-01-13.

=head1 SYNOPSIS

 use WordList::Phrase::EN::Proverb::TWW;

 my $wl = WordList::Phrase::EN::Proverb::TWW->new;

 # Pick a (or several) random word(s) from the list
 my $word = $wl->pick;
 my @words = $wl->pick(3);

 # Check if a word exists in the list
 if ($wl->word_exists('foo')) { ... }

 # Call a callback for each word
 $wl->each_word(sub { my $word = shift; ... });

 # Get all the words
 my @all_words = $wl->all_words;

=head1 STATISTICS

 +----------------------------------+------------------+
 | key                              | value            |
 +----------------------------------+------------------+
 | avg_word_len                     | 37.4152542372881 |
 | longest_word_len                 | 97               |
 | num_words                        | 472              |
 | num_words_contains_nonword_chars | 472              |
 | num_words_contains_unicode       | 0                |
 | num_words_contains_whitespace    | 472              |
 | shortest_word_len                | 13               |
 +----------------------------------+------------------+

The statistics is available in the C<%STATS> package variable.

=head1 SEE ALSO

Converted from L<Games::Word::Phraselist::Proverb::TWW> 0.01.

=head1 HOMEPAGE

Please visit the project's homepage at L<https://metacpan.org/release/WordList-Phrase-EN-Proverb-TWW>.

=head1 SOURCE

Source repository is at L<https://github.com/perlancar/perl-WordList-Phrase-EN-Proverb-TWW>.

=head1 BUGS

Please report any bugs or feature requests on the bugtracker website L<https://rt.cpan.org/Public/Dist/Display.html?Name=WordList-Phrase-EN-Proverb-TWW>

When submitting a bug or request, please include a test-file or a
patch to an existing test-file that illustrates the bug or desired
feature.

=head1 AUTHOR

perlancar <perlancar@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2016 by perlancar@cpan.org.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut


__DATA__
A friend's frown is better than a fool's smile.
A friend in need is a friend indeed.
A friend is easier lost than found.
A friend to everybody is a friend to nobody.
A problem shared is a problem halved.
A true friend is someone who reaches for your hand, but touches your heart.
False friends are worse than open enemies.
Flattery is all right so long as you don't inhale.
Give credit where credit is due.
Grief divided is made lighter.
Memory is the treasure of the mind.
Nothing dries sooner than a tear.
Old friends and old wine are best.
The best of friends must part.
The best things are not bought and sold.
There is no better looking-glass than an old friend.
To err is human (To forgive divine).
Two cannot fall out if one does not choose.
A loveless life is a living death.
Absence makes the heart grow fonder.
All's fair in love and war.
Beauty is in the eye of the beholder.
Before you meet the handsome prince you have to kiss a lot of toads.
Better to have loved and lost, than to have never loved at all.
Cold hands, warm heart.
Distance makes the heart grow fonder.
Faint heart never won fair lady.
First impressions are the most lasting.
Hatred is as blind as love.
Love and a cough cannot be hid.
Love does much but money does all.
Love levels all inequalities.
Love makes a good eye squint.
Love sees no faults.
Love sought is good, but given unsought is better.
Love to live and live to love.
Love with life is heaven; and life unloving, hell.
Man is the head but woman turns it.
Marry in haste, repent at leisure.
The course of love never did run smooth.
The Lord loveth a cheerful liar.
There is a thin line between love and hate.
To eat one's heart out.
True beauty lies within.
You can't live on bread alone.
A good friend is one's nearest relation.
A man is known by the company he keeps.
A man of straw needs a woman of gold.
A wink is as good as a nod, to a blind man.
An injury is forgiven better than an injury revenged.
Anger and hate hinder good counsel.
Appearances are deceptive.
At a round table there's no dispute about the place.
Attack is the best form of defense
Be slow in choosing, but slower in changing.
Behind every great man stands a strong woman.
Blood is thicker than water.
Cheerfulness smooths the road of life.
Confess and be hanged.
Conscience makes cowards of us all.
Don't blow your own trumpet.
Do as you would be done by.
Do unto others as you would have them do to you.
Grow angry slowly; there's plenty of time.
He bears misery best that hides it most.
He that hurts another, hurts himself.
He who wronged you will hate you.
Heavy givers are light complainers.
I am rubber and you are glue. Your words bounce off me and stick to you.
If you lose your temper, don't look for it.
It's not over till it's over.
Joy shared is double joy; grief shared is (only) half grief.
Laugh and the world laughs with you. Cry and you cry alone.
Never let the sun set on angry heart.
Never let the sun go down on your anger.
Never let the sun set on thy wrath.
Never quarrel with one's bread and butter.
No man or woman is worth your tears, and the one who is, won't make you cry.
Open confession is good for the soul.
Out of sight, out of mind.
Patience is a virtue.
Persuasion is better than force.
Spare the rod and spoil the child.
Temper is so good a thing that we should never lose it.
To the world you may be one person, but to one person, you may be the world.
Wondrous is the strength of cheerfulness.
You made your bed, now you must lie in it.
A bully is always a coward.
A handsome shoe often pinches the foot.
A good thing is all the sweeter when won with pain.
A man too careful of danger lives in continual torment.
A miss is as good as a mile.
Adversity flatters no man
Adversity and loss make a man wise
All promises are either broken or kept.
All things come to those that wait.
An eye for an eye and a tooth for a tooth.
An open door may tempt a saint.
As one door closes, another always opens.
As you go through life, make this your goal, watch the doughnut and not the hole.
Brevity is the soul of wit.
Cut your coat according to the cloth.
Discretion is the better part of valour.
Do right and fear no man.
Easy come, easy go.
Experience is the hardest teacher. She gives the test first and the lesson afterwards.
Familiarity breeds contempt.
Fortune favours the brave.
Hall binks are oft sliddery.
He who laughs last, laughs longest.
Home is where the heart is.
Hope for the best and prepare for the worst.
If wishes were horses, beggars would ride.
In the country of the blind, the one-eyed man is king.
It never rains but it pours.
Leave tomorrow till tomorrow.
Life begins at forty.
Lifes trials may be hard to bear, but patience can outlive them.
Live and learn.
Manners maketh the man.
No man is worse for knowing the worst of himself.
Only the good die young.
Procrastination is the thief of time.
The best things in life are free.
The family that prays together, stays together.
The longer you live the more you see.
The meek shall inherit the earth.
The receiver is as bad as the thief.
To wait and be patient soothes many a pang.
Up and down like a fiddler's elbow.
We cannot erase the sad records from our past.
What the eye doesn't see, the heart doesn't grieve over.
While there's life there's hope.
After dinner rest a while, after supper walk a mile.
An apple a day keeps the doctor away.
A drowning man will clutch at a straw.
An onion a day keeps everyone away.
Another pot ! Try the teapot.
As fit as a fiddle.
As hard as nails.
As sick as a dog.
As you go through life, make this your goal, watch the doughnut and not the hole.
Be not a baker if your head is made of butter.
Beauty is but skin deep.
Better late thrive than never do well.
Better to be poor and healthy rather than rich and sick.
Better to wear out than rust out.
Bread never falls but on its buttered side.
Cleanliness is next to Godliness.
Content is health to the sick and riches to the poor.
Don't bite the hand that feeds you.
Drink like a fish, water only.
Early to bed, early to rise, makes you healthy, wealthy & wise.
Fair words butter no cabbage.
Good wine ruins the purse, and bad wine ruins the stomach.
Greediness burst the bag.
Grumbling makes the loaf no larger.
Half a loaf is better than none.
He who drinks a little too much drinks much too much.
He who rises late must trot all day.
His eyes are bigger than his belly.
Hunger is the best sauce.
It is no use crying over spilt milk.
Old friends and old wine are best.
One man's meat is another man's poison.
Ready money is ready medicine.
Sound as a bell.
The nearer the bone the sweeter the meat.
The proof of the pudding is in the eating.
There's many a slip, twixt cup and the lip.
To add insult to injury.
To look as if butter will not melt in his mouth.
Too many cooks spoil the broth.
What can't be cured must be endured.
What you eat today walks and talks tomorrow.
You are what you eat.
You can't have your cake and eat it too.
You can eat an elephant if you do it one mouthful at a time.
You can't unscramble a scrambled egg.
Wondrous is the strength of cheerfulness.
A fool uttereth all his mind.
A bad excuse is better then none.
Actions speak louder than words.
Angry words fan the fire like wind.
Bad news travels fast.
Call a spade a spade.
Do as I say not as I do.
Don't advertise: Tell it to a gossip.
Don't go off half-cocked.
Few words and many deeds.
For donkeys' ages.
Gossips are frogs, they drink and talk.
He who sings drives away sorrow.
If you don't say it you will not have to unsay it.
It takes two to have an argument.
Keep your mouth shut and your eyes open.
Listen to the pot calling the kettle black.
Many a true word spoken in jest.
No news is good news.
Nothing is ill said if it is not ill taken.
One picture is worth a thousand words.
Say what you mean and mean what you say.
Self praise is no recomendation.
Silence is an excellent remedy against slander.
Silence is golden.
Silence is less injurious than a bad reply.
Since before cocky was an egg.
Speak clearly, if you speak at all.
Sticks and stones may break my bones but words will never hurt me.
Stop beating around the bush.
Take your wife's first advice.
Talking comes by nature, silence by wisdom.
A change is as good as a rest.
A stitch in time saves nine.
A throne is only a bench covered in purple velvet.
A wise man shall hold his tongue till he sees his opportunity.
Accidents will happen.
All's well that ends well.
Attack is the best means of defence.
Charity begins at home.
Different strokes for different folks.
Do not in an instant what an age cannot recompense.
Don't knock on death's door, ring the doorbell and run.
Don't try to teach your grand-mother to suck eggs.
Empty vessels make the most sound.
Empty barrels make the most noise.
Four eyes are better than two.
He who fights and runs away, lives to fight another day.
Innocent as a new born babe.
It's an ill wind that blows no-one some good.
It is better to stay silent and be thought a fool, than to open one's mouth and remove all doubt.
Necessity is the mother of invention.
No one can be caught in places he does not visit.
No wise man ever wishes to be younger.
Not in a month of Sundays.
One mans junk is another man's treasure.
Out of the frying pan into the fire.
Show a clean pair of heels.
Still waters run deep.
The darkest hour is before the dawn.
The wise shall understand.
Those who don't learn from history are doomed to repeat it.
Tomorrow is a new day.
Two heads are better than one.
You can't tell a book by its cover.
Where observation is concerned, chance favours only the prepared mind.
Where there's smoke there's fire.
Wisdom is better than strength.
Wisdom is neither inheritance nor a legacy.
Wisdom is the wealth of the wise.
Wise it is to comprehend the whole.
You can't put an old head on young shoulders.
You never know what you can do till you try.
A bad workman blames his tools
A good reputation is a fair estate.
All work and no play makes Jack a dull boy.
An idle man is the devil's playfellow.
Diligence is the mother of good luck.
Don't try kicking against the wind.
Everybody must row with the oars he has.
Hard work never did anyone any harm.
If a job is worth doing it is worth doing well.
If at first you don't succeed, try, try again.
If you can't help, don't hinder.
If you see something you like, take it and make it better.
It's all in a days work.
Laziness travels so slowly that poverty soon overtakes it.
Least talk most work.
Many hands make light work.
More haste less speed.
Needs must when the devil drives.
Never put off 'til tomorrow what you can do today.
No life can be dreary when work is a delight.
Not to break is better than to mend.
The devil finds work for idle hands.
The harder you work, the luckier you are.
The hardest work is to do nothing.
Work as if everything depends on me, but pray as if everything depends on God.
A bird in the hand is worth two in the bush.
A bird makes his nest little by little.
A cat has nine lives.
All cats are grey in the dark.
An elephant never forgets.
An old fox need learn no craft.
Birds of a feather flock together.
Curiosity killed the cat; Satisfaction brought it back.
Curses, like chickens come home to roost.
Don't count your chickens before they hatch.
Every dog has its day.
His bark is louder than his bite.
If you lie down with dogs, you'll get up with fleas.
It's an ill bird that fouls its own nest.
It's an old dog for a hard road.
It's no use closing the stable door, after the horse has bolted.
Kill two birds with the one stone.
Let sleeping dogs lie.
Like a fish out of water.
Never look a gift horse in the mouth.
No sense closing the barn door after the horse has bolted.
Nothing falls into the mouth of a sleeping fox.
Putting the cart before the horse.
Sauce for the goose is sauce for the gander.
The early bird catches the worm.
The leopard does not change his spots.
The sleepy fox catches no chickens.
There's no use in flogging a dead horse.
To scare a bird is not the way to catch it.
What do you expect from a pig, but a grunt?
When a fox hears a rabbit screaming it comes running, but not to help.
While the cats away the mice play.
You can lead a horse to water, but you can't make him drink.
You can't make a silk purse out of a sow's ear.
A chain is no stronger than its weakest link.
A rolling stone gathers no moss.
After the storm comes the calm.
All aren't hunters that blow the horn.
As green as grass.
As is the gardener so is the garden.
As you sow, so shall you reap.
Best to bend it while it's a twig.
Better to go back than go wrong.
By hook or by crook.
Deeds are fruits, words are but leaves.
Distance lends enhancement to the view.
Don't count your chickens before they are hatched.
Don't cross your bridges until you come to them.
Empty bags cannot stand upright.
Every cloud has a silver lining.
Every path has its puddle.
Fresh as a daisy.
Good company on the road is the shortest cut.
It is better to be green and growing than ripe and rotten.
Leave no stone unturned.
Like looking for a needle in a haystack.
Make hay while the sun shines.
Milk the cow but don't pull off the udder.
Never cackle unless you lay.
Oaks may fall when reeds take the storm.
Shake the hand before you plough the field.
Strike while the iron's hot.
The beaten path is safest.
The best ground bears weeds as well as flowers.
The grass is always greener on the other side of the fence.
The longest journey begins with the first step.
The longest way round is the sweetest way home.
The more you stir, the more it stinks.
The sun shines on both sides of the hedge.
The worst wheel always creaks most.
Too many irons in the fire.
Useless as a screen door on a dunny.
You can't get blood out of a stone.
A little body doth often harbour a great soul.
A point is the beginning of magnitude.
A spark can start a great fire.
A short cut is often a wrong cut.
Big fish eat little fish.
Everything has an end.
Fall seven times. Stand up eight.
First in best dressed.
From trivial things, great contests often arise.
Give them an inch and they'll take a mile.
Grow angry slowly, there's plenty of time.
He who hesitates is lost.
It's either all or nothing.
It is easier to destroy than to build.
It is the first step that is difficult.
Little strokes fell great oaks.
Lost time is never found again.
Many drops make a shower.
Mighty oaks from tiny acorns grow.
Necessity is a hard nurse, but she raises strong children.
Rome wasn't built in a day.
Seize the day
Small faults indulged let in greater.
Some of the best gifts come in small packages.
Step by step one goes far.
You have to crawl before you walk.
A bad penny always comes back.
A light purse makes a heavy heart.
A little each day is much in a year.
A man's intentions seldom add to his income.
A penny saved is a penny earned.
A poor man is better than a liar.
A single penny fairly got is worth a thousand that are not.
Always you are to be rich next year.
Beggars can't be choosers.
Better to have than to wish.
Diamonds are forever.
Every man has his price.
Every man is the architect of his destiny.
Experience is the father of wisdom.
Fair exchange is no robbery.
He has enough who is content.
He that pays last never pays twice.
He is rich that is satisfied.
In for a penny, in for a pound.
It is better to be born lucky than rich.
Little and often fill the purse.
Little thieves are hanged, but great ones escape.
Money burns a hole in your pocket.
Never spend your money before you have it.
One today is worth two tomorrows.
Penny wise, pound foolish.
Take care of the pence and the pounds will take care of themselves.
The best cast at dice is not to play.
The love of money is the root of all evil.
There is no honour among thieves.
Waste not, want not.
A good conscience is a soft pillow.
A good thing is soon snatched up.
A little knowledge is a dangerous thing.
Better safe than sorry.
Better late than never.
Business before pleasure.
Credit won by lying is quick in dying.
Damage suffered makes you knowing, but seldom rich.
Desperate diseases must have desperate remedies.
Divide and conquer.
Don't rely on the label on the bag.
Don't throw the baby out with the bath-water.
Don't put all your eggs in one basket.
Experience is the best teacher.
First come, first served.
Fore-warned is fore-armed.
Hasty climbers have sudden falls.
Hasty judgements are generally faulty.
Honesty is the best policy.
If anything can go wrong, it will.
If you don't know where you're going, then the journey is never ending.
It's a poor job that can't carry one boss.
Let the buyer beware.
Look before you leap.
Nobody can serve two masters.
One false move may lose the game.
One man's loss, is another man's gain.
Peace begins just where ambition ends.
Possession is nine tenths of the law.
Rules are made to be broken.
The customer is always right.
The gods help them that help themselves.
The golden age never was the present one.
To each his own.
We do not always gain by changing.
Where there's a will there's a way.
A fool and his money are soon parted.
A fool in a gown is none the wiser.
A wise man doesn't need advice, and a fool won't take it.
Advice when most needed is least heeded.
Always in a hurry, always behind.
Cheap is dear in the long run.
Confess and be hanged.
Cut off one's nose to spite one's face.
Empty vessels make the most noise.
Facts do not cease to exist because they are ignored.
Fools rush in where angels fear to tread.
He who won't be advised, can't be helped.
If the cap fits, wear it.
In one ear and out the other.
It can't happen here is number one on the list of famous last words.
It is better to stay silent and be thought a fool, than to open one's mouth and remove all doubt.
One of these days is none of these days.
Pride cometh before a fall.
Pride feels no pain.
See nothing, say nothing, know nothing.
The bigger they are the harder they fall.
The fool wanders, the wise man travels.
The hood does not make the monk.
The wise man is deceived once but the fool twice.
There is no fool like an old fool.
Use not today what tomorrow will need.
What's the good of home, if you are never in it?
You cannot lose what you never had.
