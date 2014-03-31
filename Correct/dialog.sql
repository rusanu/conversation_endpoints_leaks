:on error exit
use master;
go

if @@trancount > 0
	rollback
go


use [source];
go

begin tran;
declare @h uniqueidentifier;
begin dialog conversation @h
	from service [source_service]
	to service N'target_service'
	with encryption = off;
send on conversation @h;
commit;
go