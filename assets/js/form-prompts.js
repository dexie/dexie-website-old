document.addEventListener('DOMContentLoaded', ()=>{
  const emailRegexp = /^[a-zA-Z0-9.!#$%&’*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*$/;
  $('#emailAddressInput').on('keyup', ev => {
    if (ev.keyCode === 13) {
      $('#applyBetaBtn').click();
    }
  });
  /*$('.sign-up-beta-btn').on("click", ()=>{
    $('#signup-form').slideDown(()=>$('#emailAddressInput').focus());
    if (typeof ga !== "undefined") ga('send', 'event', 'buttons', 'click', 'sign-up-beta-btn');
  });*/
  $('.applyBetaBtn').on('click', ()=>{
    $('.sign-up-beta-btn').prop("disabled", true);
    $('.applyBetaBtn').prop("disabled", true);
    const emailInput = $('#emailAddressInput');
    const email = emailInput.val();
    function trackInput() {
      if (emailRegexp.test(emailInput.val())) {
        $('#emailAddrAlert').hide();
        $('.applyBetaBtn').prop("disabled", false);
        emailInput.off('input', trackInput);
      }
    }
    if (!emailRegexp.test(email)) {
      $('#emailAddrAlert').show();
      emailInput.on('input', trackInput);
      return;
    }
    $('#signup-form').slideUp(2000);
    $('#form-prompts-spinner').show();
    $('#form-prompts').slideDown(1000);

    function handleRequest(request) {
      $('.applyBetaBtn').prop("disabled", false);
      $('#form-prompts-spinner').hide();
      if (request) {
        formPrompts("form-prompts-area", request, (action, data) => {
          $('#form-prompts-area').html("");
          $('#form-prompts-spinner').show();
          window.scrollTo(0,0);
          postIt(action, data).then(request => {
            handleRequest(request);
          }).catch(console.error).then(()=>{
            $('#form-prompts-spinner').hide();
          });
        }, ()=>{
          $('#form-prompts').slideUp();
        });
      } else {
        console.error("No request we got");
      }
    }
    postIt("sign-up-beta", {email}).then(handleRequest).catch(console.error);
  });

  function postIt (action, data) {
    return fetch(`https://dexie.cloud/api/public/action/${encodeURIComponent(action)}`, {
      method: "POST",
      headers: {
        'Accept': 'application/json',
        "Content-Type": "application/json",
      },
      body: JSON.stringify(data)
    }).then(res => res.json());
  }

  function formPrompts(id, request, respond, complete) {
    const area = document.getElementById(id);
    area.innerHTML = "";
    //window.scrollTo(0,0); 

    const {message, prompts, action, actionData, completed} = request;

    if (message) {
      $(area).append(fixMessage(message));
    }
    if (prompts) {
      if (Array.isArray(prompts)) {
        prompts.forEach(addInput);
      } else {
        addInput(prompts);
      }
    }

    function addInput(prompt) {
      const {message, type} = prompt;
      if (message) {
        $(area).append(fixMessage(message, "prompts-sub-message"));
      }
      switch (type) {
        case "confirm": {
          const {active, inactive} = prompt;
          if (!prompt[active] || !prompt[inactive]) {
            console.error("Missing request's active / inactive flow");
          }
          // The choice should lead us further:
          $(area).append($('<button class="btn btn-primary prompts-confirm prompts-confirm-active" />').text(active).on('click', ()=>{
            const request = prompt[active];
            formPrompts(id, request, respond, complete);
          }));
          $(area).append($('<button class="btn btn-primary prompts-confirm prompts-confirm-inactive" />').text(inactive).on('click', ()=>{
            const request = prompt[inactive];
            formPrompts(id, request, respond, complete);
          }));
          break;
        }
        case "text": {
          const {name, title} = prompt;
          $(area).append($('<div>').append($('<input type="text" />').attr({
            autocomplete: name,
            name,
            title
          })));
          break;
        }
        case "select": {
          const {name, choices} = prompt;
          const div = $('<div class="prompts-select">').appendTo(area);
          choices.forEach(choice => {
            const {value, title} = choice;
            const innerDiv = $('<div class="prompts-select prompts-select-item">').appendTo(div);
            innerDiv.append($('<input type="radio" />').attr("name", name).val(value));
            innerDiv.append($('<span>').text(' ' + title));
          });
          break;
        }
        case "multiselect": {
          const {name, choices} = prompt;
          const hidden = $('<input type="hidden">').attr("name", name);
          const div = $('<div class="prompts-multiselect">').appendTo(area);
          div.append(hidden);
          choices.forEach(choice => {
            const {value, title} = choice;
            const innerDiv = $('<div>').appendTo(div);
            innerDiv.append($('<input type="checkbox">').val(value).on("click", updateHidden));
            innerDiv.append($('<span>').text(' ' + title));
          });
          function updateHidden() {
            const a = [];
            div.find("input[type='checkbox']").each(function() {
              if (this.checked) a.push(this.value);
            });
            hidden.val(a.join(','));
          }
          break;
        }
      }
    }

    if (action) $(area).append($('<br/><button class="btn btn-primary prompts-action">Submit</button>')
      .on('click', ()=>{
        const inputs = $(area).find(':input');
        const response = Object.assign({}, actionData);
        inputs.each(function() {
          if (this.name) {
            if (this.type === "radio") {
              if (this.checked) response[this.name] = this.value;
            } else {
              response[this.name] = this.value;
            }
          }
        });
        respond(action, response);
      }));

    if (completed) {
      const doneBtn = $('<button autofocus class="btn btn-success">Done</button>')
        .on('click', ()=>{
          $('.sign-up-beta-btn').html(`
            <span class='glyphicon glyphicon-ok'></span>
            <span>Signed up</span>`
          )
          complete();
        });
      $(area).append(doneBtn);

    }
  }


  function fixMessage(message, clazz) {
    return message
      .trim()
      .split('\n')
      .map(line => line.trim())
      .join('\n')
      .split('\n\n') // Only create new <p> if double newline
      .map(line => {
        const result = $('<p class="prompts-message" />');
        if (clazz) result.addClass(clazz);
        result.text(line);
        return result;
      });
  }
});
