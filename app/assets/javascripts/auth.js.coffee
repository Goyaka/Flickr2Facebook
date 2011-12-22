$(document).ready -> 
    if fb_user and flickr_user
        $.ajax
            url: '/flickr/sets'
            type: 'get'
            data: { user: fb_user }
            dataType: 'json'
            beforeSend: (xhr, settings) ->
                $("#sets").html('<center><img src= "assets/loading.gif"></center')
            success: (data) ->
                $("#sets").html('');
                $("#sets_list_template").tmpl(data).appendTo("#sets").animate();