# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://jashkenas.github.com/coffee-script/

$(document).ready -> 
    if fb_user and flickr_user
        $.ajax
            url: '/flickr/sets'
            type: 'get'
            data: { user: user }
            dataType: 'json'
            beforeSend: (xhr, settings) ->
                $("#sets").html('<center><img src= "assets/loading.gif"></center')
            success: (data) ->
                $("#sets").html('');
                $("#sets_list_template").tmpl(data).appendTo("#sets").animate();
    
    