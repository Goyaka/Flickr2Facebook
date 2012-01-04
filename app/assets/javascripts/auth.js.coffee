Array::remove = (e) -> @[t..t] = [] if (t = @indexOf(e)) > -1

isScrolledIntoView = (elem)->
    docViewTop = $(window).scrollTop();
    docViewBottom = docViewTop + $(window).height();

    elemTop = $(elem).offset().top;
    elemBottom = elemTop + $(elem).height();

    ((elemBottom >= docViewTop) && (elemTop <= docViewBottom));
    
@scrollImportButton = scrollImportButton =->
    if('.import-sets-placemark')
        if(isScrolledIntoView('.import-sets-placemark'))
            $('.import-sets-button').css('position','relative')
            $('.import-sets-button').css('border','0 none')
        else
            $('.import-sets-button').css('position','fixed')
            $('.import-sets-button').css('bottom','0')
            $('.import-sets-button').css('border-top','1px #ccc solid')
        

addCheckHandlers =->
    $('.set label').click ->
        check = ($(this).find('.check'))
        image = ($(this).find('.thumb'))
        if ($(this).parent().find('input').attr('checked') != 'checked')
            check.addClass('selected')
            image.addClass('selected')
        else
            check.removeClass('selected')
            image.removeClass('selected')
            $(this).focus ->                
                check.css('visibility','hidden')
            $(this).blur ->
                $(this).unbind('hover')
                
                

@sourcesToLoad = sourcesToLoad = []
@loadSetsToMigrate = loadSetsToMigrate = (api, template, source)->
    
    updateLoadingMessage =->
        if sourcesToLoad.length == 0    
            $('.loading-box').hide()
        else
            loadingtext = 'Loading your '  + sourcesToLoad.join(' and ' ) + ' albums'
            $('.loading-message').html(loadingtext)
            $('.loading-box').show()
    
    $.ajax
        url: api
        type: 'get'
        dataType: 'json'
        beforeSend: (xhr, settings) ->
            sourcesToLoad.push(source)
            updateLoadingMessage()
            
        success: (data) ->
            if data.hasOwnProperty 'fb_albums'
                set['fb_albums'] = data['fb_albums'][set['id']] for set in data.sets
                
            $(template).tmpl(data).appendTo('.sets');
            
            #Add checkbox handlers-
            addCheckHandlers()
        
            scrollImportButton()
            
            sourcesToLoad.remove(source)
            updateLoadingMessage()
            $('.import-sets-button').show()
            #add select all handler
            if $('#select_all')
                $('#select_all').click ->
                    if ($('#select_all').attr('checked'))
                        $('.sets input').attr('checked',true)
                        $('.sets .check').addClass('selected')
                        $('.sets .thumb').addClass('selected')
                    else
                        $('.sets input').attr('checked',false)
                        $('.sets .check').removeClass('selected')
                        $('.sets .thumb').removeClass('selected')
            


@loadSetStatus = loadSetStatus =-> 
    $.ajax
        url: '/photos/upload-status'
        type: 'get'
        dataType: 'json'
        beforeSend: (xhr, settings) ->
            $('#queue').html('<center><img src= "assets/loading.gif"><br> Loading photos in upload queue </center>')
        success: (data) ->
            target = '#queue'
            $(target).html('')
            
            $('#flickr_status_template').tmpl(data).appendTo(target);
            $('#picasa_status_template').tmpl(data).appendTo(target);
                        
                                        
$(document).ready -> 
    $().dropdown()
    
        