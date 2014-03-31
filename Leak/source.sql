:on error exit
use master;
go

if @@trancount > 0
	rollback
go

if db_id('source') is not null
begin
	alter database [source] set single_user with rollback immediate;
	drop database [source];
end
go

create database [source];
go

use [source];
go

create queue [q];
go

create service [source_service] on queue [q];
go

create route [target] with service_name = N'target_service', 
	address = 'tcp://localhost:4022';
go

create procedure usp_source
as
begin
	set nocount on;
	declare @h uniqueidentifier, @mt sysname;

	begin transaction;

	receive top(1) @mt = message_type_name, @h = conversation_handle from q;
	if (@mt = N'http://schemas.microsoft.com/SQL/ServiceBroker/EndDialog' or
		@mt = N'http://schemas.microsoft.com/SQL/ServiceBroker/Error')
	begin
		end conversation @h;
	end
	commit
end
go

alter queue q with activation (
	status = on, 
	max_queue_readers = 1, 
	procedure_name = [usp_source], 
	execute as  owner);
go