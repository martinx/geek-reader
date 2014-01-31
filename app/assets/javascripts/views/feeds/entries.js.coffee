class Reader.Views.Entries extends Backbone.View
  tagName: "div"
  className: "content"
  template: JST["entries"]

  initialize: (options) ->
    @title = options.title
    @$el.html @template({title: @title, entries: @collection})
    @id = @title.toString().replace(/\s/g, "_")
    @$el.attr("id", @id)

    @listenTo @collection, "reset", @render_entries
    @listenTo @collection, "add", @render_entry
    @listenTo @collection, "refreshed", @refreshed

    @page = 0 # page start from 0
    @head = null
    @$("ul.entries").on "scroll", => @scroll.apply(@)

    # keep a reference to all views
    @entry_views = {}

  render_entries: (entries) ->
    @$(".loader").remove()
    @$("ul.entries").empty()
    models = entries.models
    @head = models[0]
    _.each(models, (e)=> @render_entry(e))
    @check_scroll()

#    "click [class$=refresh]": "refresh_feed"
  events:
    "click .menu_toggle": "toggle_menu"
    "click .brand" : "toggle_feed_menu"
    "click ul.dropdown-menu a[data-mark]" : "mark_read"
    "click ul.dropdown-menu a.refresh" : "refresh_source"

  mark_read: (ev)->
    @$(".head").removeClass("open")
    age = $(ev.target).data("mark")
    @collection.mark_read(age)
    return false

  refresh_source: ->
    @$(".head").removeClass("open")
    @collection.refresh()
    return false

  toggle_feed_menu: ->
    @$(".head").toggleClass("open")

  toggle_menu: ->
    $("body>.container").toggleClass("show_menu")

  scroll: (ev)->
    log "scroll event"
    clearTimeout(@scroll_detector) if @scroll_detector?
    @scroll_detector = setTimeout (=> @check_scroll()), 500

  check_scroll: ->
    log "check scroll, state is #{@state}"
    return if @state is "nomore"
    scroll_el = @$("ul.entries")
    scroll_bottom = scroll_el.scrollTop() + scroll_el.height()
    actual_height = scroll_el[0].scrollHeight
    log "scroll_bottom: #{scroll_bottom} actual_height: #{actual_height} state: #{@state}"
    if actual_height - scroll_bottom < 4 and @state isnt "loading"
      warn "getting more entries"
      @state = "loading"
      scroll_el.append("<li class='more'>loading more ...</li>")
      @page += 1
      req = $.getJSON(@collection.url+"?page="+@page)
      req.done (entries)=>
        @collection.add(entries)
        @state = "loaded"
        @$("li.more").remove()
      req.fail (jXhr, text, status)=>
        @state = "nomore"
        @$("li.more").html("No more") if status is "Not Found"

  refreshed: ->
#    @$(".refresh").removeClass("loading")
    flash = $("<div class='flash alert alert-success'>feed is updated successfully! </div>")
    flash.appendTo(@$el)
    setTimeout ( -> flash.fadeOut()), 4000

  refresh_feed: ->
    @collection.refresh()
#    @$(".refresh").addClass("loading")

  render_entry: (entry)->
    entry_view = new Reader.Views.Entry({model:entry, parent: @})
    idx = @collection.indexOf(entry) + 1
    insert_before = null
    while idx < @collection.length
      e = @collection.at(idx)
      if @entry_views["entry_#{e.id}"]?
        insert_before = @entry_views["entry_#{e.id}"]
        break
      idx = idx + 1
    if insert_before?
      @$(".entries").append(entry_view.render().el)
      $(entry_view.render().el).insertBefore(insert_before.el)
    else
      @$(".entries").append(entry_view.render().el)

    @entry_views["entry_#{entry.id}"] = entry_view

  set_opened_entry: (entryView)->
    @opened_entry?.close()
    @opened_entry = entryView

  render: ->
    @

  load: ->
    @collection.fetch(reset: true, error: => @$(".entries").html("No entries available"))
