###

The Keyboard class provides a rendering of
a piano keyboard that can color notes as they
are played.  Example:

await loadscript '/lib/keyboard.coffee', defer()
k = new Keyboard
k.play "[CEG]"

The function "play" uses the same ABC notation
that is used with the built in Pencil Code play
function.  Google for "ABC notation" on the web.

Here is a an example that with tempo, beats,
a rest, a semitone, an octave, and a chord:

k.play {tempo: 150}, "c G/2 G/2 A G z B [_B,CEGc]"

Implementation notes: for speed, keyboard drawing
is done with raw canvas commands.

A specific key can be highlighted by just saying
something like this:

k.draw(64, blue)

The number used is the midi number for the key,
where 60 is middle C.

###

colors12 = [
  '#db4437' # google red
  '#ff5722' # orange
  '#f4b400' # google yellow
  '#ffeb3b' # yellow
  '#cddc39' # lime
  '#0f9d58' # google green
  '#00bcd4' # teal
  '#03a9f4' # light blue
  '#4285f4' # google blue
  '#673ab7' # deep purple
  '#9c27b0' # purple
  '#e91e63' # pink
]

class Keyboard extends Sprite
  ###
  The constructor accepts an optional object with any
  subset of the following properties:
    keys: the number of keys (for example, 88 or 36 or 12)
    width: the pixel width of the whole keyboard
    height: the pixel height of the whole keyboard
    lowest: the midi number of the lowest key
    lineWidth: the pixel width of keyboard outline strokes
    color: the color to use for the white keys
    blackColor: the color to use for the black keys
    lineColor: the color to use for outlines
  If any subset of the options are chosen, then reasonable
  defaults are chosen for everything else.
  ###
  constructor: (options = {}) ->
    @lineWidth = options.lineWidth ? 1.6
    @color = options.color ? 'white'
    @blackColor = options.blackColor ? 'black'
    @lineColor = options.lineColor ? 'black'
    extra = Math.ceil(@lineWidth)
    defwidth = 422
    # If you just specify a number of keys, we will pick a default size.
    if options.keys?
      numwhite = Math.ceil(options.keys / 12 * 7)
      aspect = numwhite / 5
      defwidth = Math.sqrt(42000 * aspect) + extra
    # Default aspect ratio is figurd from the keys requested, or 4.2
    # if no keys were requested. If all is given is an overall sprite
    # width or height, then the aspect ratio is used to pick the other.
    # If both are given, and keys are not, then the number of keys is
    # picked based on shape.  If all three are specified, then the
    # keys are deformed to fit.
    width = options.width ? if options.height?
       Math.round((options.height - extra) * (aspect ? 4.2) + extra)
    else
       defwidth
    height = options.height ? Math.round((width - extra) / (aspect ? 4.2) + extra)
    if not options.keys?
      numwhite = Math.max(1, Math.round((width - extra) / (height - extra) * 5))
    # Get midi key numbers for the key range, defaulting to centered at 'F'.
    firstwhite = Math.floor(42 - (numwhite - 1) / 2)
    lastwhite = Math.ceil(firstwhite + numwhite - 1)
    @lowest = options.lowest ? Keyboard.mcp(firstwhite)
    if options.keys?
      @highest = @lowest + options.keys - 1
    else
      @highest = Math.max(@lowest, Keyboard.mcp(Keyboard.wcp(@lowest) + numwhite - 1))
    # OK, now after applying options, how many white keys?
    firstwhite = Keyboard.wcp(@lowest)
    lastwhite = Keyboard.wcp(@highest)
    if (Keyboard.keyshape(@highest) >= 8)
      lastwhite += 1
    numwhite = lastwhite - firstwhite + 1

    # Calculate some geometry constants for the keyboard:
    @kw = (width - extra) / numwhite    # white key width, height
    @kh = (options.height ? @kw * 5 + extra) - extra
    @bkw = @kw * 4 / 7                  # black key width
    @bkh = @kh * 3 / 5                  # black key height
    @halfex = extra / 2                 # offset to center lines
    @horiz =
      left: firstwhite * @kw            # left boundary
      right: (lastwhite + 1) * @kw      # right boundary
    @ckw = (3 * @kw - 2 * @bkw) / 3     # top width of the c key
    @fkw = (4 * @kw - 3 * @bkw) / 4     # top width of the f key
    # Render the keyboard as its own sprite
    # that can be moved around.
    super
      width: Math.ceil(@horiz.right - @horiz.left + extra)
      height: Math.ceil(@kh + extra)
    do @drawall

  # Calculates the bounding left and right pixel positions
  # given the lowest and higest keys to render.
  calcHoriz: () ->
    leftmost = Keyboard.wcp(@lowest)
    rightmost = Keyboard.wcp(@highest) + 1
    # if the highest key is a black key
    # then go right one more space
    if (Keyboard.keyshape(@highest) >= 8)
      rightmost += 1
    return {
      left: leftmost * @kw
      right: rightmost * @kw
    }

  # white-key position, used for locating a
  # key horizontally: given a midi key number,
  # caculates a "white key number"
  # that increases by 1 for every white
  # key, or that is the next lower white
  # key number for every black key.
  @wcp: (n) ->
    floor((n + 7) / 12 * 7)

  # the inverse of wcp: given a wcp number,
  # translates to a midi key position.
  @mcp: (n) ->
    ceil(n / 7 * 12) - 7

  # A code for the shape of the key number.
  # C,D,E,F,G,A,B are 1,2,3,4,5,6,7 and
  # C#,D#,F#,G#,A# are 8,9,10,11,12.
  @keyshape: (n) ->
    [1,8,2,9,3,4,10,5,11,6,12,7][((n % 12) + 12) % 12]

  # A colorful color to use for the key number.
  @keycolor: (n) ->
    colors12[(n % 12 + 12) % 12]

  # Override Turtle.play to intercept the callback.
  play: ->
    args = Array.prototype.slice.call(
      arguments, 0)
    if (args.length <= 0 or
        not $.isPlainObject(args[0]))
      args.unshift({})
    args[0].callback = @makecallback(
      args[0].callback)
    Sprite.prototype.play.apply(this, args)

  # Draw the nth key with the given fillcolor.
  # Here n is specified as a midi number for the
  # key, i.e., 60 is middle C.
  draw: (n, fillcolor) ->
    if not (@lowest <= n <= @highest)
      return
    if not fillcolor?
      if Keyboard.keyshape(n) >= 8
        fillcolor = @blackColor
      else
        fillcolor = @color
    ctx = @canvas().getContext '2d'
    ctx.save()
    ctx.beginPath()
    @keyoutline(ctx, n)
    ctx.fillStyle = fillcolor
    ctx.strokeStyle = @lineColor
    ctx.lineWidth = @lineWidth
    ctx.fill()
    ctx.stroke()
    ctx.restore()

  # Draw the entire keyboard with default colors
  # (i.e., white and black
  drawall: ->
    for n in [@lowest..@highest]
      @draw(n)

  # Creates a callback closure for listening to
  # play events and formatting keys.
  makecallback: (cb2) ->
    # keep track of keys that have been colored.
    pressed = []
    # convertfreq converts a Hz frequency to
    # the closest midi number.
    convertfreq = (f) ->
      round(69 + ln(f / 440) * 12 / ln(2))
    callback = (d) =>
      for p in pressed
        @draw(p)
      pressed.length = 0
      if not d?.frequency then return
      for f in d.frequency
        midikey = convertfreq f
        pressed.push midikey
        @draw midikey, Keyboard.keycolor midikey
      if cb2
        cb2(d)
    return callback

  # A utility function for generating the path outline
  # of the key with midi number n.
  keyoutline: (ctx, n) ->
    # startx will be the left edge of the key rectangle.
    # Here we compute it exactly for white keys and get
    # the closest white key position for black keys.
    # Black keys will further modify startx below.
    startx = @halfex + @kw * Keyboard.wcp(n) - @horiz.left
    starty = @halfex
    ks = Keyboard.keyshape(n)
    # key shapes are modified for the lowest
    # and highest keys on the piano.
    leftmost = n is @lowest
    rightmost = n is @highest
    # White keys can have cut-in corners, so lcx will
    # be the left corner width and rcx is the right
    # cut-in corner width, to be computed below.
    lcx = 0
    rcx = 0
    switch ks
      when 1
        rcx = @kw - @ckw
      when 2
        rcx = lcx = (@kw - @ckw) / 2
      when 3
        lcx = @kw - @ckw
      when 4
        rcx = @kw - @fkw
      when 5
        lcx = @fkw + @bkw - @kw
        rcx = 2 * @kw - 2 * @fkw - @bkw
      when 6
        lcx = 2 * @kw - 2 * @fkw - @bkw
        rcx = @fkw + @bkw - @kw
      when 7
        lcx = @kw - @fkw
      when 8
        startx += @ckw
      when 9
        startx += 2 * @ckw + @bkw - @kw
      when 10
        startx += @fkw
      when 11
        startx += 2 * @fkw + @bkw - @kw
      when 12
        startx += 3 * @fkw + 2 * @bkw - 2 * @kw
    # Cut-in corners are not cut-in for the leftmost
    # or rightmost key.
    if leftmost then lcx = 0
    if rightmost then rcx = 0
    if ks >= 8
      # draw black keys
      ctx.moveTo(startx, starty + @bkh)
      ctx.lineTo(startx + @bkw, starty + @bkh)
      ctx.lineTo(startx + @bkw, starty)
      ctx.lineTo(startx, starty)
      ctx.closePath()
    else
      # draw white keys
      ctx.moveTo(startx, starty + @kh)
      ctx.lineTo(startx + @kw, starty + @kh)
      ctx.lineTo(startx + @kw, starty + @bkh)
      ctx.lineTo(startx + @kw - rcx, starty + @bkh)
      ctx.lineTo(startx + @kw - rcx, starty)
      ctx.lineTo(startx + lcx, starty)
      ctx.lineTo(startx + lcx, starty + @bkh)
      ctx.lineTo(startx, starty + @bkh)
      ctx.closePath()

# Export the Keyboard class as a global.
window.Keyboard = Keyboard
