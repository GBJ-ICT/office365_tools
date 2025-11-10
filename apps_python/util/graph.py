# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

# <UserAuthConfigSnippet>
from configparser import SectionProxy
from azure.identity import DeviceCodeCredential
from msgraph import GraphServiceClient
from msgraph.generated.users.item.user_item_request_builder import UserItemRequestBuilder
from msgraph.generated.users.item.mail_folders.item.messages.messages_request_builder import (
    MessagesRequestBuilder)
from msgraph.generated.users.item.send_mail.send_mail_post_request_body import (
    SendMailPostRequestBody)
from msgraph.generated.models.message import Message
from msgraph.generated.models.item_body import ItemBody
from msgraph.generated.models.body_type import BodyType
from msgraph.generated.models.recipient import Recipient
from msgraph.generated.models.email_address import EmailAddress

class Graph:
    settings: SectionProxy
    device_code_credential: DeviceCodeCredential
    user_client: GraphServiceClient

    def __init__(self, config: SectionProxy):
        self.settings = config
        client_id = self.settings['clientId']
        tenant_id = self.settings['tenantId']
        graph_scopes = self.settings['graphUserScopes'].split(' ')

        self.device_code_credential = DeviceCodeCredential(client_id, tenant_id = tenant_id)
        self.user_client = GraphServiceClient(self.device_code_credential, graph_scopes)
# </UserAuthConfigSnippet>

    # <GetUserTokenSnippet>
    async def get_user_token(self):
        graph_scopes = self.settings['graphUserScopes']
        access_token = self.device_code_credential.get_token(graph_scopes)
        return access_token.token
    # </GetUserTokenSnippet>

    # <GetUserSnippet>
    async def get_user(self):
        # Only request specific properties using $select
        query_params = UserItemRequestBuilder.UserItemRequestBuilderGetQueryParameters(
            select=['displayName', 'mail', 'userPrincipalName']
        )

        request_config = UserItemRequestBuilder.UserItemRequestBuilderGetRequestConfiguration(
            query_parameters=query_params
        )

        user = await self.user_client.me.get(request_configuration=request_config)
        return user
    # </GetUserSnippet>

    # <GetInboxSnippet>
    async def get_inbox(self):
        query_params = MessagesRequestBuilder.MessagesRequestBuilderGetQueryParameters(
            # Get at most 25 results
            top=top,
        )
        request_config = MessagesRequestBuilder.MessagesRequestBuilderGetRequestConfiguration(
            query_parameters= query_params
        )

        messages = await self.user_client.me.mail_folders.by_mail_folder_id('inbox').messages.get(
                request_configuration=request_config)
        return messages
    # </GetInboxSnippet>

    # <SendMailSnippet>
    async def send_mail(self, subject: str, body: str, recipient: str):
        message = Message()
        message.subject = subject

        message.body = ItemBody()
        message.body.content_type = BodyType.Text
        message.body.content = body

        to_recipient = Recipient()
        to_recipient.email_address = EmailAddress()
        to_recipient.email_address.address = recipient
        message.to_recipients = []
        message.to_recipients.append(to_recipient)

        request_body = SendMailPostRequestBody()
        request_body.message = message

        await self.user_client.me.send_mail.post(body=request_body)
    # </SendMailSnippet>

    # <MakeGraphCallSnippet>
    async def make_graph_call(self):
        # INSERT YOUR CODE HERE
        return
    # </MakeGraphCallSnippet>

    # <GetTeamsSnippet>
    async def get_teams(self):
        """Fetch all teams the user is a member of"""
        teams = await self.user_client.me.joined_teams.get()
        return teams
    # </GetTeamsSnippet>

    # <GetChannelsSnippet>
    async def get_channels(self, team_id: str):
        """Fetch all channels in a team"""
        channels = await self.user_client.teams.by_team_id(team_id).channels.get()
        return channels
    # </GetChannelsSnippet>

    # <GetChannelMessagesSnippet>
    async def get_channel_messages(self, team_id: str, channel_id: str, top: int = 50):
        """Fetch messages from a channel"""
        query_params = MessagesRequestBuilder.MessagesRequestBuilderGetQueryParameters(
            top=top,
        )
        request_config = MessagesRequestBuilder.MessagesRequestBuilderGetRequestConfiguration(
            query_parameters=query_params
        )

        messages = await self.user_client.teams.by_team_id(team_id).channels.by_channel_id(
            channel_id).messages.get(request_configuration=request_config)
        return messages
    # </GetChannelMessagesSnippet>

    # <ExportTeamsChannelsSnippet>
    async def export_teams_channels(self, output_file: str = 'teams_export.json'):
        """Export all teams, channels, and messages to JSON file"""
        import json
        from datetime import datetime

        export_data = {
            'export_date': datetime.now().isoformat(),
            'teams': []
        }

        # Get all teams
        teams_result = await self.get_teams()
        teams = teams_result.value if teams_result.value else []

        for team in teams:
            team_data = {
                'id': team.id,
                'displayName': team.display_name,
                'channels': []
            }

            # Get channels for this team
            channels_result = await self.get_channels(team.id)
            channels = channels_result.value if channels_result.value else []

            for channel in channels:
                channel_data = {
                    'id': channel.id,
                    'displayName': channel.display_name,
                    'messages': []
                }

                # Get messages from channel (limit to last 50)
                try:
                    messages_result = await self.get_channel_messages(team.id, channel.id, top=50)
                    messages = messages_result.value if messages_result.value else []

                    for msg in messages:
                        message_data = {
                            'id': msg.id,
                            'from': msg.from_.user.display_name if msg.from_ and msg.from_.user else 'Unknown',
                            'body': msg.body.content if msg.body else '',
                            'createdDateTime': msg.created_date_time.isoformat() if msg.created_date_time else None
                        }
                        channel_data['messages'].append(message_data)
                except Exception as e:
                    print(f"Error fetching messages from channel {channel.display_name}: {str(e)}")

                team_data['channels'].append(channel_data)

            export_data['teams'].append(team_data)

        # Write to JSON file
        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(export_data, f, indent=2, ensure_ascii=False)

        print(f"Export completed. Data saved to {output_file}")
        return export_data
    # </ExportTeamsChannelsSnippet>

    # <ExportSpecificChannelSnippet>
    async def export_specific_channel(self, team_id: str, channel_id: str, output_file: str = 'teams_export.json'):
        """Export messages from a specific team and channel to JSON file"""
        import json
        from datetime import datetime

        export_data = {
            'export_date': datetime.now().isoformat(),
            'team_id': team_id,
            'channel_id': channel_id,
            'messages': []
        }

        try:
            # Get channel details
            channel = await self.user_client.teams.by_team_id(team_id).channels.by_channel_id(channel_id).get()
            export_data['channel_name'] = channel.display_name if channel.display_name else 'Unknown'

            # Get all messages from the channel (fetch in batches)
            all_messages = []
            messages_result = await self.get_channel_messages(team_id, channel_id, top=50)
            
            if messages_result.value:
                all_messages.extend(messages_result.value)

            # Process messages
            for msg in all_messages:
                message_data = {
                    'id': msg.id,
                    'from': msg.from_.user.display_name if msg.from_ and msg.from_.user else 'Unknown',
                    'body': msg.body.content if msg.body else '',
                    'createdDateTime': msg.created_date_time.isoformat() if msg.created_date_time else None
                }
                export_data['messages'].append(message_data)

            # Write to JSON file
            with open(output_file, 'w', encoding='utf-8') as f:
                json.dump(export_data, f, indent=2, ensure_ascii=False)

            print(f"Export completed. {len(all_messages)} messages saved to {output_file}")
            return export_data

        except Exception as e:
            print(f"Error exporting channel: {str(e)}")
            return None
    # </ExportSpecificChannelSnippet>
