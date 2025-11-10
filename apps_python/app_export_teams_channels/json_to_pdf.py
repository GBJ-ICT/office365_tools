import json
from reportlab.lib.pagesizes import letter, A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import inch
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak, Table, TableStyle
from reportlab.lib import colors
from datetime import datetime

def json_to_pdf(json_file: str, pdf_file: str):
    """Convert Teams channel export JSON to formatted PDF"""
    
    # Read JSON file
    with open(json_file, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    # Create PDF
    doc = SimpleDocTemplate(pdf_file, pagesize=A4, topMargin=0.5*inch, bottomMargin=0.5*inch)
    story = []
    styles = getSampleStyleSheet()
    
    # Custom styles
    title_style = ParagraphStyle(
        'CustomTitle',
        parent=styles['Heading1'],
        fontSize=24,
        textColor=colors.HexColor('#1E53A3'),
        spaceAfter=12,
        alignment=1  # center
    )
    
    channel_style = ParagraphStyle(
        'ChannelTitle',
        parent=styles['Heading2'],
        fontSize=14,
        textColor=colors.HexColor('#B6424C'),
        spaceAfter=6,
        spaceBefore=6
    )
    
    message_style = ParagraphStyle(
        'Message',
        parent=styles['Normal'],
        fontSize=9,
        spaceAfter=8,
        leftIndent=0.2*inch
    )
    
    meta_style = ParagraphStyle(
        'Meta',
        parent=styles['Normal'],
        fontSize=7,
        textColor=colors.grey,
        spaceAfter=4
    )
    
    # Title
    story.append(Paragraph(f"Teams Channel Export", title_style))
    story.append(Paragraph(f"Channel: {data.get('channel_name', 'Unknown')}", channel_style))
    story.append(Spacer(1, 0.2*inch))
    
    # Export metadata
    export_date = data.get('export_date', 'Unknown')
    team_id = data.get('team_id', 'N/A')
    channel_id = data.get('channel_id', 'N/A')
    msg_count = len(data.get('messages', []))
    
    metadata = f"<b>Export Date:</b> {export_date}<br/><b>Messages:</b> {msg_count}<br/><b>Team ID:</b> {team_id}"
    story.append(Paragraph(metadata, meta_style))
    story.append(Spacer(1, 0.3*inch))
    
    # Messages
    messages = data.get('messages', [])
    for idx, msg in enumerate(messages, 1):
        # Message header with sender and date
        sender = msg.get('from', 'Unknown')
        created_date = msg.get('createdDateTime', 'No date')
        
        msg_header = f"<b>{sender}</b> • {created_date}"
        story.append(Paragraph(msg_header, meta_style))
        
        # Message body (HTML content)
        body = msg.get('body', '')
        if body:
            # Clean up HTML
            body = body.replace('<p>', '').replace('</p>', '<br/>')
            body = body.replace('<at id=', '<i>@').replace('</at>', '</i>')
            
            try:
                story.append(Paragraph(body, message_style))
            except:
                # Fallback if HTML parsing fails
                story.append(Paragraph(body.replace('<', '&lt;').replace('>', '&gt;'), message_style))
        
        # Separator
        story.append(Spacer(1, 0.1*inch))
        
        # Page break every 15 messages
        if idx % 15 == 0:
            story.append(PageBreak())
    
    # Build PDF
    doc.build(story)
    print(f"PDF created: {pdf_file}")

if __name__ == '__main__':
    json_to_pdf('teams_export.json', 'teams_export.pdf')