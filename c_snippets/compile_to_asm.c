void
cpl_dec_ptr(int inc)
{
	if (inc < -127)
	{
		puts("LONG DEC PTR");
	}
	else
	{
		puts("SHORT DEC PTR");
	}
}

void
cpl_inc_ptr(int inc)
{
	if (inc > 127)
	{
		puts("LONG INC PTR");
	}
	else
	{
		puts("SHORT INC PTR");
	}
}

void
cpl_chg_ptr(int inc)
{
	if (inc == 0) puts("SKIP");
	if (inc < 0) cpl_dec_ptr(inc);
	else cpl_inc_ptr(inc);
}