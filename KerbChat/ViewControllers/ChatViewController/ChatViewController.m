//
//  ChatViewController.m
//  KerbChat
//
//  Created by Anton Rodick on 29.05.15.
//  Copyright (c) 2015 Anton Rodick. All rights reserved.
//

#import "ChatViewController.h"
#import "SRWebSocket.h"
#import "KerbChatManager.h"
#import "ChatHelper.h"
#import "AuthHelper.h"

@interface ChatViewController () <SRWebSocketDelegate, UITableViewDelegate, UITableViewDataSource>

@property (weak, nonatomic) IBOutlet UITableView *messageTableView;
@property (weak, nonatomic) IBOutlet UITextView *messageTextView;
@property (weak, nonatomic) IBOutlet UIButton *sendButton;
@property (nonatomic, strong) NSMutableArray *messages;

@end

@implementation ChatViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.messages = [NSMutableArray array];
    self.messageTextView.layer.borderWidth = 1.0f;
    self.messageTextView.layer.borderColor = [[UIColor lightGrayColor] CGColor];
    [[KerbChatManager manager] setSocketDelegate:self];
    [self sendGoRoomMessageWithName:self.roomName];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}


#pragma mark
#pragma mark Socket Delegate methods

- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error
{
    NSLog(@":( Websocket Failed With Error %@", error);
    [[KerbChatManager manager] removeSocket];
}

- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message;
{
    NSDictionary *json = [[ChatHelper helper] decryptedJsonFromServer:message];
    NSString *messageType = [json valueForKey:@"type"];
    [self handlingReceiveMessage:json withType:messageType];
}

- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean
{
    NSLog(@"WebSocket closed");
    [[KerbChatManager manager] removeSocket];
}

#pragma mark
#pragma mark Sending methods

- (BOOL)sendMessage:(NSString*) message
{
    [[KerbChatManager manager] sendSocketMessage:message];
    return YES;
}

- (void)sendGoRoomMessageWithName:(NSString*) name {
    NSString *encryptedJson = [[ChatHelper helper] jsonForGoRoomWithName:name];
    if ([self sendMessage:encryptedJson]) {
        NSLog(@"Send go_room message");
    }
}

- (void)sendMessageAboutNewMessage {
    NSString *room = [[[KerbChatManager manager] rooms] valueForKey:self.roomName];
    NSString *jsonToSend = [[ChatHelper helper] jsonForMessageRequestFromUser:[[AuthHelper helper] login]
                                                                  withMessage:self.messageTextView.text
                                                                      andRoom:room];
    if ([self sendMessage:jsonToSend]) {
        NSLog(@"Your message sent to room");
    }
}

- (void)sendSecretMessageWithRoom:(NSString*) room {
    NSString *encryptedJson = [[ChatHelper helper] jsonForSecretWithRoom:room];
    if ([self sendMessage:encryptedJson]) {
        NSLog(@"Send secret message");
    }
}

#pragma mark
#pragma mark Receive methods

- (void)handlingReceiveMessage:(NSDictionary*) message withType:(NSString*) type {
    if ([type isEqualToString:@"online"]) {
        NSLog(@"---- %@ ---- Received JSON with online type : %@",[message valueForKey:@"timestamp"], message);
        NSMutableDictionary *rooms = [NSMutableDictionary dictionary];
        for (NSDictionary *room in [message valueForKey:@"rooms"]) {
            [rooms setValue:room forKey:[room valueForKey:@"name"]];
        }
        [[KerbChatManager manager] setRooms:rooms];
        [[KerbChatManager manager] setOnlineUsers:[message valueForKey:@"users_online"]];
        if ([[[KerbChatManager manager] rooms] valueForKey:self.roomName] == nil) {
            [[ChatHelper helper] showAlertToCloseRoom];
            [self.navigationController popViewControllerAnimated:YES];
            return;
        }

        return;
    }
    if ([type isEqualToString:@"room_messages"]) {
        NSLog(@"Received JSON with room_msg type : %@", message);
        [self reloadMessages:message];
        return;
    }
    if ([type isEqualToString:@"new_message"]) {
        NSLog(@"Received JSON with new_msg type : %@", message);
        [self addNewReceivedMessage:message];
        return;
    }
    if ([type isEqualToString:@"get_secret"]) {
        NSLog(@"Received JSON with get_secret type : %@",message);
        NSString *room = [[message valueForKey:@"room"] valueForKey:@"name"];
        [self sendSecretMessageWithRoom:room];
        return;
    }
}

#pragma mark
#pragma mark Table View delegate & data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.messages count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                      reuseIdentifier:CellIdentifier];
    }
    cell.textLabel.font = [UIFont fontWithName:@"Helvetica-Light" size:16];
    cell.textLabel.text = [self.messages[indexPath.row] valueForKey:@"text"];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ in %@",
                                 [self.messages[indexPath.row] valueForKey:@"from"],
                                 [self.messages[indexPath.row] valueForKey:@"time"]];
    return cell;
}

-(void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

-(CGFloat) tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    return 1;
}

#pragma mark
#pragma mark

- (void)addNewReceivedMessage:(NSDictionary*) message {
    [self.messages addObject:[[message valueForKey:@"new_message"] valueForKey:@"message"]];
    [self.messageTableView reloadData];
}

- (void)reloadMessages:(NSDictionary*) message {
    [self.messages removeAllObjects];
    NSArray *receivedMessages = [message valueForKey:@"messages"];
    for (NSDictionary *message in receivedMessages) {
        [self.messages addObject:message];
    }
    [self.messageTableView reloadData];
}

-(IBAction)sendMessageToChat:(id)sender {
    [self sendMessageAboutNewMessage];
    self.messageTextView.text = @"";
}

@end
