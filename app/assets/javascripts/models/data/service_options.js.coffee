ns = @edsc.models.data

ns.ServiceOptions = do (ko, KnockoutModel = @edsc.models.KnockoutModel, extend = $.extend) ->

  class SubsetOptions
    constructor: (@config) ->
      @parameters = for parameter in @config.parameters
        extend({selected: ko.observable(true)}, parameter)

      @formats = @config.formats

      @formatName = ko.observable(@formats[0].name)
      @format = ko.computed =>
        name = @formatName()
        for format in @formats
          return format if format.name == name
        null

      @subsetToSpatial = ko.observable(true)

    serialize: ->
      result = {format: @formatName()}
      if @format()?.canSubset
        result.spatial = @config.spatial if @subsetToSpatial()
        result.parameters = (p.id for p in @parameters when p.selected())
      result

    fromJson: (jsonObj) ->
      this

  class ServiceOptions
    constructor: (method, @availableMethods) ->
      @method = ko.observable(method)
      @isValid = ko.observable(true)

      @subsetOptions = ko.observable(null)

      @options = ko.computed =>
        m = @method()
        result = null
        if @availableMethods
          for available in @availableMethods when available.name == m
            result = available
            break
        if result?.subset
          @subsetOptions(new SubsetOptions(result))
        else
          @subsetOptions(null)
        result

    serialize: ->
      method = @method()
      result = {method: method, model: @model, rawModel: @rawModel}
      for available in @availableMethods
        if available.name == method
          result.type = available.type
          result.id = available.id
          break
      result.subset = @subsetOptions()?.serialize()
      result

    fromJson: (jsonObj) ->
      @method(jsonObj.method)
      @model = jsonObj.model
      @rawModel = jsonObj.rawModel
      @type = jsonObj.type
      @orderId = jsonObj.order_id
      @subsetOptions()?.fromJson(jsonObj.subset) if jsonObj.subset
      this

  class ServiceOptionsModel extends KnockoutModel
    constructor: (@granuleAccessOptions) ->
      @accessMethod = ko.observableArray()
      @isLoaded = @computed
        read: =>
          opts = @granuleAccessOptions()
          methods = opts.methods
          result = methods?
          @_onAccessOptionsLoad(opts) if result
          result
        deferEvaluation: true

      @canAddAccessMethod = ko.observable(false)
      @readyToDownload = @computed(@_computeIsReadyToDownload, this, deferEvaluation: true)

    _onAccessOptionsLoad: (options) ->
      availableMethods = options.methods
      methods = @accessMethod.peek()
      for method in methods
        method.availableMethods = availableMethods
      if options.defaults
        @fromJson(options.defaults)
      else
        @addAccessMethod() if methods.length == 0 && availableMethods.length > 0
      @canAddAccessMethod(availableMethods.length > 1 ||
        (availableMethods.length == 1 && availableMethods[0].type != 'download'))

    _computeIsReadyToDownload: ->
      return false unless @isLoaded()
      return true if @granuleAccessOptions().methods?.length == 0

      for m in @accessMethod()
        return false unless m.method()? && m.isValid()
      true

    addAccessMethod: =>
      @accessMethod.push(new ServiceOptions(null, @granuleAccessOptions().methods))

    removeAccessMethod: (method) =>
      @accessMethod.remove(method)

    serialize: ->
      {accessMethod: (m.serialize() for m in @accessMethod())}

    fromJson: (jsonObj) ->
      @accessMethod.removeAll()
      for json in jsonObj.accessMethod
        method = new ServiceOptions(null, @granuleAccessOptions().methods)
        method.fromJson(json)
        @accessMethod.push(method)
      this

  exports = ServiceOptionsModel
