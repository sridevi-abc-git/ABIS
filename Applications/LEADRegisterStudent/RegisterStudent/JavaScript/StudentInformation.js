$(document).ready(function ()
{
	var cellphone;

	jQuery('#firstName').validation('add', {
		validator: '^[ -~]+$', required: true, message: {
			REQUIRED: 'Please enter your first name.'
		}
	});

	jQuery('#lastName').validation('add', {
		validator: '^[ -~]+$', required: true, message: {
			REQUIRED: 'Please enter your last name.'
		}
	});

	jQuery('#cellPhone1').validation('add', {
		validator: VAL_NUMBER_3, required: false, message: {
			INVALID: ''
		}
	});
	jQuery('#cellPhone1').autotab({ format: 'number', target: '#cellPhone2' });

	jQuery('#cellPhone2').validation('add', {
		validator: VAL_NUMBER_3, required: false, message: {
			INVALID: ''
		}
	});
	jQuery('#cellPhone2').autotab({ format: 'number', target: '#cellPhone3', previous: '#cellPhone1' });

	jQuery('#cellPhone3').validation('add', {
		validator: VAL_NUMBER_4, required: false, message: {
			INVALID: ''
		}
	});
	jQuery('#cellPhone3').autotab({ format: 'number', target: '#email2', previous: '#cellPhone2' });

	jQuery('#email').validation('add', {
		validator: VAL_EMAIL, required: true, message: {
			REQUIRED: 'Please enter valid email address.',
			INVALID: 'Invalid email address entered.'
		}
	});

	jQuery('#email2').validation('add', {
		validator: VAL_EMAIL, message: {
			INVALID: 'Invalid email address entered.'
		}
	});
	jQuery('#email2').blur(function (event) { jQuery(this).blank(event, { destination: 'email', source: 'email2' }) });
	jQuery('#email2').mouseout(function (event) { jQuery(this).blank(event, { destination: 'email', source: 'email2' }) });
	jQuery('#email2').focus(function (event) { jQuery(this).restore(event, { destination: 'email', source: 'email2' }) });
	jQuery('#email2').mouseover(function (event) { jQuery(this).restore(event, { destination: 'email', source: 'email2' }) });


	jQuery('#reemail').validation('add', {
		validator: VAL_EMAIL, required: true, message: {
			REQUIRED: 'Please enter valid email address.',
			INVALID: 'Invalid email address entered.'
		}
	});

	jQuery('#reemail2').validation('add', {
		validator: VAL_EMAIL, message: {
			INVALID: 'Invalid email address entered.'
		}
	});

	jQuery('#reemail2').blur(function (event) { jQuery(this).blank(event, { destination: 'reemail', source: 'reemail2' }) });
	jQuery('#reemail2').mouseout(function (event) { jQuery(this).blank(event, { destination: 'reemail', source: 'reemail2' }) });
	jQuery('#reemail2').focus(function (event) { jQuery(this).restore(event, { destination: 'reemail', source: 'reemail2' }) });
	jQuery('#reemail2').mouseover(function (event) { jQuery(this).restore(event, { destination: 'reemail', source: 'reemail2' }) });

	cellphone = jQuery('#cellPhone').val();
	jQuery('#cellPhone1').val(cellphone.substring(0, 3))
	jQuery('#cellPhone2').val(cellphone.substring(3, 6))
	jQuery('#cellPhone3').val(cellphone.substring(6))
});

function ValInput()
{
	var valid = true;
	var length;
	var err_ctrl;

	// validate input
	valid &= jQuery("#firstName").validation('val');
	valid &= jQuery("#lastName").validation('val');
	valid &= jQuery("#cellPhone1").validation('val');
	valid &= jQuery("#cellPhone2").validation('val');
	valid &= jQuery("#cellPhone3").validation('val');

	if (!jQuery("#email").validation('val'))
	{
		valid = false;
		jQuery("#email2").css({ 'color': 'red', 'background-color': '#ffD0D0' });
	}
	else
	{
		jQuery("#email2").css({ 'color': 'inherit', 'background-color': 'inherit' });
	}

	if (!jQuery("#reemail").validation('val'))
	{
		valid = false;
		jQuery("#reemail2").css({ 'color': 'red', 'background-color': '#ffD0D0' });
	}
	else
	{
		jQuery("#reemail2").css({ 'color': 'inherit', 'background-color': 'inherit' });
	}

	if (valid)
	{
		jQuery("#cellPhone").val(jQuery("#cellPhone1").val() + jQuery("#cellPhone2").val() + jQuery("#cellPhone3").val())
		length = jQuery("#cellPhone").val().length;
		if (length > 0 && length < 10)
		{
			valid = false;
			if (jQuery("#cellPhone1").val().length == 0) jQuery("#cellPhone1").css({ 'color': 'red', 'background-color': '#ffD0D0' });
			if (jQuery("#cellPhone2").val().length == 0) jQuery("#cellPhone2").css({ 'color': 'red', 'background-color': '#ffD0D0' });
			if (jQuery("#cellPhone3").val().length == 0) jQuery("#cellPhone3").css({ 'color': 'red', 'background-color': '#ffD0D0' });
		}

		err_ctrl = jQuery("#reemail")[0].id + '_err';

		if (jQuery("#email").val().toUpperCase() != jQuery("#reemail").val().toUpperCase())
		{

			jQuery('#' + err_ctrl).text('Re-entered email addresses does not match first email address').css('color', 'red').show();
			jQuery("#reemail").css({ 'color': 'red', 'background-color': '#ffD0D0' });

			valid = false;
		}
		else
		{
			jQuery('#' + err_ctrl).hide();
			jQuery("#reemail").css({ 'color': '', 'background-color': '' });
		}
	}
	return valid;
}

(function($)
{
	$.fn.blank = function (event, options)
	{
		var settings    = $.extend({blank: "".repeat(20, 'X')}, options);
		var source		= $('#' + settings.source);
		var destination = $('#' + settings.destination);

		if ((source.val() != settings.blank) && (!source.is(':focus')))
		{
			switch (event.type)
			{
				case 'mouseout':
				case 'blur':
					destination.val(source.val());
					if (destination.val().length > 0) source.val(settings.blank);

					err_ctrl = $('#' + destination[0].id + '_err').hide();
					break;
			}
		}
	};

	$.fn.restore = function (event, options)
	{
		var source = $('#' + options.source);
		var destination = $('#' + options.destination);

		if (destination.val().length > 0)
		{
			switch (event.type)
			{
				case 'focus':
					source.val(destination.val()).select();
					break;

				case 'mouseover':
					source.val(destination.val());
					break;
			}
		}
	};


}(jQuery));

String.prototype.repeat = function(count, char)
{
	var results = '';
	while (count--) results += char;
	return results;
}
