$(document).ready(function ()
{
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

	jQuery('#cellPhone').validation('add', {
		validator: VAL_PHONE, required: false, message: {
			INVALID: 'Invalid phone number entered.'
		}
	});

	jQuery('#email').validation('add', {
		validator: VAL_EMAIL, required: true, message: {
			REQUIRED: 'Please enter valid email address.',
			INVALID: 'Invalid email address entered.'
		}
	});

	jQuery('#reemail').validation('add', {
		validator: VAL_EMAIL, required: true, message: {
			REQUIRED: 'Please enter valid email address.',
			INVALID: 'Invalid email address entered.'
		}
	});
});

function PassFailChange(listName, boxname)
{
	var checkBox;
	var buttonList;

	checkBox = document.getElementById(boxname);
	buttonList = document.getElementById(listName);

	for (var x = 0; x < buttonList.cells.length; x++)
	{

		if (buttonList.cells[x].firstChild.checked)
		{
			if (buttonList.cells[x].firstChild.value != 'NoShow')
			{
				checkBox.disabled = false;
				checkBox.checked = true;
			}
			else
			{
				checkBox.disabled = true;
				checkBox.checked = false;
			}
		}
	}
}

function valRosterChanges()
{
	var valid = true;

	jQuery(":text", "#tbody").each(function ()
	{
		valid &= jQuery(this).validation('val');
	});

	return (valid == 1);
}

function ValNewStudent()
{
	var valid = true;
	
	jQuery('#msg').hide();

	// validate input
	valid &= jQuery("#firstName").validation('val');
	valid &= jQuery("#lastName").validation('val');
	valid &= jQuery("#cellPhone").validation('val');
	valid &= jQuery("#email").validation('val');
	valid &= jQuery("#reemail").validation('val');

	if (valid)
	{
		var err_ctrl = jQuery("#reemail")[0].id + '_err';

		if (jQuery("#email").val() != jQuery("#reemail").val())
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


