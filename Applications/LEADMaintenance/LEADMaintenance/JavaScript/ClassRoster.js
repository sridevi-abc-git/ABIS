
$(document).ready(function ()
{
	$('#basic-modal .basic').click(function (e)
	{
		$('#basic-modal-content').modal();
		return false;
	})
});

function PassFailChange(listName, boxname)
{
	var gridview;
	var checkBox;
	var buttonList;

	checkBox = document.getElementById(boxname);
	buttonList = document.getElementById(listName);

	for (var x = 0; x < buttonList.cells.length; x++)
	{

		if (buttonList.cells[x].firstChild.checked)
		{
			if (buttonList.cells[x].firstChild.value == 'Pass')
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

function NewStudent()
{
	jQuery("input", "#addStudentPanel").val('');
}


