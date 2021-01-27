"use strict";

function $(id) { return document.getElementById(id); }
function $$(selectors) { return document.querySelectorAll(selectors); }

/**
 * 
 */
function censusApp () {
    setupLinks();
}
/**
 * 
 */
function setupLinks() {
    $$('aside > a').forEach(function (el) {
        if (!el.hash) { return; }

        el.hash = '#/' + el.hash.substr(1);
        el.onclick = scrollToLink;
    })

    window.addEventListener('scroll', visibleLinks);
    window.addEventListener('resize', visibleLinks);
}
/**
 * 
 */
function scrollToLink(e) {
    e.preventDefault = true;

    var hash = e.target.hash.substr(2);

    var target = $(hash);

    if (target) {
        target.scrollIntoView({
            behavior: 'smooth'
        });

        visibleLinks();
    }
}
/**
 * 
 */
function visibleLinks() {
    var height = (window.innerHeight || document.documentElement.clientHeight);
    var width = (window.innerWidth || document.documentElement.clientWidth);

    $$('aside > a').forEach(function (el) {
        if (!el.hash) { return; }

        var hash = el.hash.substr(2);
        
        var target = $(hash);

        var rect = target.getBoundingClientRect();

        if (rect.top >= 0 && rect.left >= 0 && rect.bottom <= height && rect.right <= width) {
            el.classList.add('visible');
        } else {
            el.classList.remove('visible');
        }
    })
}

this.addEventListener('load', censusApp);