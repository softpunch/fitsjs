require('jDataView/src/jdataview')
Module      = require('module')
Decompress  = require('fits.decompress')
Header      = require('fits.header')
Data        = require('fits.data')
Image       = require('fits.image')
BinTable    = require('fits.bintable')
CompImage   = require('fits.compressedimage')
Table       = require('fits.table')

# Header data unit to store a header and its associated data unit
class HDU

  constructor: (header, data)->
    @header = header
    @data   = data
  
  hasData: -> return if @data? then true else false
  
  # ### API
  
  # Returns the value from the header of the user specifed key
  getCard: (key) -> return @header[key]

# File is the class that parses all the HDUs, initializes Header instances
# and appropriate Data instances.
class File
  @LINEWIDTH   = 80
  @BLOCKLENGTH = 2880

  constructor: (buffer) ->
    @length     = buffer.byteLength
    @view       = new jDataView buffer, undefined, undefined, false
    @hdus       = []
    @eof        = false

    loop
      header = @readHeader()
      data = @readData(header)
      hdu = new HDU(header, data)
      @hdus.push(hdu)
      break if @eof

  # ##Class Methods

  # Determine the number of characters following a header or data unit
  @excessBytes: (length) -> return File.BLOCKLENGTH - (length) % File.BLOCKLENGTH

  # ##Instance Methods

  # Read a header unit and initialize a Header object
  readHeader: ->
    linesRead = 0
    header = new Header()
    loop
      line = @view.getString(File.LINEWIDTH)
      linesRead += 1
      header.readCard(line)
      break if line[0..3] is "END "

    # Seek to the next relavant block in file
    excess = File.excessBytes(linesRead * File.LINEWIDTH)
    @view.seek(@view.tell() + excess)
    @checkEOF()

    return header

  # Read a data unit and initialize an appropriate instance depending
  # on the type of data unit (e.g. image, binary table, ascii table).
  # Note: Bytes are not interpretted by this function.  That is left 
  #       to the user to call when the data is needed.
  readData: (header) ->
    return unless header.hasDataUnit()
    
    if header.isPrimary() and header.hasDataUnit()
      data = new Image(@view, header)
      # if FITS.Image?
      #   data = new Image(@view, header)
      # else
      #   throw "The Image class must be loaded by the user"
    else if header.isExtension()
      if header.extensionType is "BINTABLE"
        if header.contains("ZIMAGE")
          data = new CompImage(@view, header)
        else
          data = new BinTable(@view, header)
      else if header.extensionType is "TABLE"
        data = new Table(@view, header)
    excess = File.excessBytes(data.length)

    # Forward to the next HDU
    @view.seek(@view.tell() + data.length + excess)
    @checkEOF()
    return data

  checkEOF: -> @eof = true if @view.tell() is @length

  # Count the number of HDUs
  count: -> return @hdus.length 
  
  # ### API
  
  # Returns the first HDU containing a data unit.  An optional argument may be passed to retreive 
  # a specific HDU
  getHDU: (index = undefined) ->
    if index? and @hdus[index]?
      return @hdus[index]
    for hdu in @hdus
      return hdu if hdu.hasData()
  
  # Returns the header associated with the first HDU containing a data unit.  An optional argument
  # may be passed to point to a specific HDU.
  getHeader: (index = undefined) -> return @getHDU().header
  
  # Returns the data object associated with the first HDU containing a data unit.  This method does not read from the array buffer
  # An optional argument may be passed to point to a specific HDU.
  getDataUnit: (index = undefined) -> return @getHDU().data

  # Returns the data associated with the first HDU containing a data unit.  An optional argument
  # may be passed to point to a specific HDU.
  getData: (index = undefined) -> return @getHDU().data.getData()


FITS = @FITS    = {}
module?.exports = FITS

FITS.version    = '0.0.1'
FITS.File       = File
FITS.HDU        = HDU