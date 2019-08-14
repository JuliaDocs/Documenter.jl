// libraries: jquery, katex, katex-auto-render
// arguments: $, katex, renderMathInElement

$(document).ready(function() {
  renderMathInElement(
    document.body,
    {
      delimiters: [
        {left: "$", right: "$", display: false},
        {left: "\\[", right: "\\]", display: true},
        {left: "$$", right: "$$", display: true},
      ],
    }
  );
})
// FIXME do we need this?
// window.WebFontConfig = {
//   custom: {
//     families: ['KaTeX_AMS', 'KaTeX_Caligraphic:n4,n7', 'KaTeX_Fraktur:n4,n7',
//       'KaTeX_Main:n4,n7,i4,i7', 'KaTeX_Math:i4,i7', 'KaTeX_Script',
//       'KaTeX_SansSerif:n4,n7,i4', 'KaTeX_Size1', 'KaTeX_Size2', 'KaTeX_Size3',
//       'KaTeX_Size4', 'KaTeX_Typewriter'],
//   },
// };
