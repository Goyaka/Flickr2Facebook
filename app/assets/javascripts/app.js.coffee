$ ->
    $('.links a').click ->
        nodeid = this.id
        $('.faq .snippet').hide()
        console.log('hi')
        expand = '#' + nodeid + '-expand'
        console.log
        $(expand).show()
        return false
        