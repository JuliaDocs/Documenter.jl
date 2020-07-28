// libraries: jquery
// arguments: $

function round(value) {
  if (value > 999) {
    const digits = +((value - 950) % 1000 > 99)
    return `${((value + 1) / 1000).toFixed(digits)}k`
  } else {
    return value.toString()
  }
}

$(document).ready(function(){
  gotorepo = $('#documenter-go-to-repo')
  $.getJSON(`https://api.github.com/repos/${repo_owner}/${repo_name}`, function( data ) {
    li = $('<li>').append(`${round(data.stargazers_count || 0)} Stars`)
    gotorepo.append(li)
    li = $('<li>').append(`${round(data.forks_count || 0)} Forks`)
    gotorepo.append(li)
  });
});