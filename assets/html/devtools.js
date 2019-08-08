'use strict'

define(["jquery"], function($) {
  console.log("initializing devtools")
  class DevToolBox extends HTMLElement {
    constructor() {
      super();

      var shadow = this.attachShadow({mode: 'open'});

      var style = document.createElement('style');
      style.textContent = `
      :host {
        all: initial;
        display: block;
        width: 20em;
        height: 15em;
        position: fixed;
        bottom: 1em;
        right: 1em;
        border: 1px solid #b9b9b9;
        background-color: #b1dfbbee;
      }

      header {
          font-weight: bold;
          background-color: #59a66aed;
          border-bottom: 1px solid #b9b9b9;
          text-align: center;
      }
      .themepicker button {
        width: 100%;
      }
      .themepicker ul {
        margin-left: 0;
        margin-right: 1.5em;
      }
      .uicomponents {
        display: flex;
        flex-direction: column;
      }
      .hidden {
        display: none;
      }
      h1 {
        font-size: large;
      }
      `;
      shadow.appendChild(style);

      var devtools_html = $.parseHTML(`
        <article>
          <header>Documenter devtools</header>
          <div class="themepicker">
            <h1>Themes</h1>
            <ul>
            <li><button type="button" class="themepicker-button" data-themefile="documenter.css">Default</button></li>
            <li><button type="button" class="themepicker-button" data-themefile="darkly.css">Darkly</button></li>
            <!-- <li><button type="button" class="themepicker-button" data-themefile="documenter-rainbow.css">Rainbow</button></li> -->
            <!-- <li><button type="button" class="themepicker-button" data-themefile="documenter-dark.css">Dark</button></li> -->
            </ul>
          </div>
          <hr />
          <div class="uicomponents">
            <button type="button" id="dev-btn-hidelogo">Toggle logo</button>
            <button type="button" id="dev-btn-hidetitle">Toggle sidebar title</button>
            <button type="button" id="dev-btn-showversion">Toggle version selector</button>
          </div>
        </article>
      `);
      $.each(devtools_html, $.proxy(function(i,e) {
        console.log(i, e);
        shadow.append(e);
      }, this));

      this._shadow = shadow;
    }

    registerThemeLink(linktag) {
      //this._linktag = linktag;
      var container = this._shadow.querySelector("article");

      $(this._shadow.querySelector('.themepicker')).removeClass("hidden");

      function themepick_callback(ev){
        var transition_style = $('<style>');
        transition_style.html(`
          * {
            transition: all .3s;
          }
        `);
        console.log(transition_style);
        var transition_style_element = $('head').append(transition_style);
        var themefile = ev.target.getAttribute('data-themefile')
        console.log("Click!", themefile, ev, ev.target);
        linktag.href = themefile;
        console.log(linktag);
        //transition_style_element.remove(transition_style);
        // TODO: the transition needs to be more sophisticated. Let's instead append a new
        // <link> for the new theme to <head>, wait for the transition and then remove the
        // old theme <link> and the transition style.
        setTimeout(function() {
          transition_style.remove();
        }, 2000);
      }

      for(let e of container.getElementsByClassName('themepicker-button')) {
        e.addEventListener('click', themepick_callback, false);
      }

      this._shadow.getElementById('dev-btn-hidelogo').addEventListener('click', function(ev) {
        $('#documenter > .docs-sidebar > .docs-logo').toggle();
      }, false);
      this._shadow.getElementById('dev-btn-hidetitle').addEventListener('click', function(ev) {
        $('#documenter > .docs-sidebar > .docs-package-name').toggle();
      }, false);
      this._shadow.getElementById('dev-btn-showversion').addEventListener('click', function(ev) {
        $('#documenter .docs-version-selector').toggleClass("visible");
      }, false);
    }
  }
  window.customElements.define('jldebug-devtools', DevToolBox);

  return {
    appendWidget: function(body_elements) {
      var devbox = document.createElement('jldebug-devtools');
      $(devbox).hide();
      $.each(body_elements, function(i, e) {
        e.appendChild(devbox);
      });
      return devbox;
    },
  }
});
