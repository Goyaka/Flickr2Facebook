$(document).ready -> 
    if typeof fb_user != "undefined" and typeof flickr_user != "undefined"
        loadsets = (api, picker) -> 
            $.ajax
                url: api
                type: 'get'
                data: { user: fb_user }
                dataType: 'json'
                beforeSend: (xhr, settings) ->
                    selector = picker.replace('#','') + '-container';
                    $("#sets").append('<div id="' + selector + '"></div>')
                    $("#" + selector).html('<center><img src= "assets/loading.gif"><br>This may take a while, depending upon your Flickr Sets!</center>')
                success: (data) ->
                    selector = picker.replace('#','') + '-container';
                    $('#' + selector).html('');
                    $(picker).tmpl(data).appendTo('#' + selector).animate();
                    
                    #add select all handler
                    if $('#select_all')
                        $('#select_all').click ->
                            if ($('#select_all').attr('checked'))
                                $('.sets input').attr('checked',true)
                            else
                                $('.sets input').attr('checked',false)
                    
                    $.each (data.sets),  (index, set) ->
                        $.ajax
                            url: 'flickr/cover-photo'
                            type: 'get'
                            data: { primary: set.primary }
                            dataType: 'json'
                            success: (coverData) ->
                                $("#"+ set.primary).attr('src', coverData.cover_image)
            
        if $("#sets_list_template").length != 0
            loadsets('/flickr/sets','#sets_list_template')
            
        if $('#inqueue_sets_list_template').length != 0
            loadsets('/flickr/inqueue_sets','#inqueue_sets_list_template')
            
        if $("#uploading_sets_list_template").length != 0
            loadsets('/flickr/uploading_sets','#uploading_sets_list_template')
        
        if $("#uploaded_sets_list_template").length != 0
            loadsets('/flickr/uploaded_sets','#uploaded_sets_list_template')
            
            
        
        