$(document).ready -> 
    if typeof fb_user != "undefined" and typeof flickr_user != "undefined"
        loadsets = (api, picker, target, load_message) -> 
            $.ajax
                url: api
                type: 'get'
                data: { user: fb_user }
                dataType: 'json'
                beforeSend: (xhr, settings) ->
                    $(target).html('<center><img src= "assets/loading.gif"><br>' + load_message + '</center>')
                success: (data) ->
                    $(target).html('');
                    $(picker).tmpl(data).appendTo(target);
                    
                    #add select all handler
                    if $('#select_all')
                        $('#select_all').click ->
                            if ($('#select_all').attr('checked'))
                                $('.sets input').attr('checked',true)
                            else
                                $('.sets input').attr('checked',false)
            
        if $("#sets_list_template").length != 0
            loadsets('/flickr/sets','#sets_list_template', '#sets', 'Loading your flickr sets')
            
        if $('#inqueue_sets_list_template').length != 0
            loadsets('/flickr/inqueue_sets','#inqueue_sets_list_template', '#queue', 'Loading photos in upload queue')
                    
        if $("#uploaded_sets_list_template").length != 0
            loadsets('/flickr/uploaded_sets','#uploaded_sets_list_template', '#done', 'Loading uploaded photos')
            
            
        
        