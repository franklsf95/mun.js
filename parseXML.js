function parseLog(x) {
	xml = $.parseXML(x);
	$(xml).find("Conference").each(function() {
		console.log(getChild(this, 'abbreviation'));
		$(this).find("Session").each(function() {
			console.log(this);
		});
	});
}

function getChild(t, str) {
	return $(t).children(str).text();
}