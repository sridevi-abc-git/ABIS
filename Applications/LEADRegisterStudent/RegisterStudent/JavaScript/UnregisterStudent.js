

$(document).ready(function ()
{

	jQuery('#txtEmailAddress').validation('add', {
		validator: VAL_EMAIL, required: true, message: {
			REQUIRED: 'Please enter valid email address.',
			INVALID: 'Invalid email address entered.'
		}
	});

	jQuery('#txtConfirmationNumber').validation('add', {
		validator: VAL_NUMBER, required: false, message: {
			INVALID: 'Invalid confirmation number entered.'
		}
	});

});

function ValInput()
{
	var valid = true;
	// validate input
	valid &= jQuery("#txtEmailAddress").validation('val');
	valid &= jQuery("#txtConfirmationNumber").validation('val');

	return valid;
}

