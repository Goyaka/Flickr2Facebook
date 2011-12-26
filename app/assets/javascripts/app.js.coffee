$ ->
    $('.links a').click ->
        nodeid = this.id
        $('.faq .snippet').hide()
        expand = '#' + nodeid + '-expand'
        $(expand).show()
        return false
    
