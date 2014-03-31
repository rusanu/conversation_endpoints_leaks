:on error exit
use master;
go

if @@trancount > 0
	rollback
go

if db_id('target') is not null
begin
	alter database [target] set single_user with rollback immediate;
	drop database [target];
end
go

create database [target];
go

use [target];
go

create queue [q];
go

create service [target_service] on queue [q] ([DEFAULT]);
go

grant send on service::[target_service] to [public];
go

create route [source] with service_name = N'source_service', 
	address = 'tcp://localhost:4022';
go

create procedure usp_target
as
begin
	set nocount on;
	declare @h uniqueidentifier, @mt sysname;

	begin transaction;

	receive top(1) @mt = message_type_name, @h = conversation_handle from q;
	if (@mt = N'http://schemas.microsoft.com/SQL/ServiceBroker/EndDialog' or
		@mt = N'http://schemas.microsoft.com/SQL/ServiceBroker/Error' or 
		@mt = N'DEFAULT')
	begin
		end conversation @h;
	end
	commit
end
go

alter queue q with activation (
	status = on, 
	max_queue_readers = 1, 
	procedure_name = [usp_target], 
	execute as  owner);
go

