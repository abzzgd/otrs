# --
# Copyright (C) 2001-2018 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

my $Selenium = $Kernel::OM->Get('Kernel::System::UnitTest::Selenium');

$Selenium->RunTest(
    sub {

        my $Helper       = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');
        my $ChangeObject = $Kernel::OM->Get('Kernel::System::ITSMChange');

        # Get change state data.
        my $ChangeStateDataRef = $Kernel::OM->Get('Kernel::System::GeneralCatalog')->ItemGet(
            Class => 'ITSM::ChangeManagement::Change::State',
            Name  => 'pending pir',
        );

        # Create test change, we need a long description and justification to show the history details.
        my $ChangeTitleRandom = 'ITSMChange ' . $Helper->GetRandomID();
        my $ChangeID          = $ChangeObject->ChangeAdd(
            ChangeTitle => $ChangeTitleRandom,
            Description =>
                "Test Description with a very very very very very very very very very very very very very very very very long text",
            Justification =>
                "Test Justification with a very very very very very very very very very very very very very very very very long text",
            ChangeStateID => $ChangeStateDataRef->{ItemID},
            UserID        => 1,
        );
        $Self->True(
            $ChangeID,
            "Change in Pending PIR state is created",
        );

        # Create and log in test user.
        my $TestUserLogin = $Helper->TestUserCreate(
            Groups => [ 'admin', 'itsm-change', 'itsm-change-builder', 'itsm-change-manager' ]
        ) || die "Did not get test user";

        $Selenium->Login(
            Type     => 'Agent',
            User     => $TestUserLogin,
            Password => $TestUserLogin,
        );

        my $ScriptAlias = $Kernel::OM->Get('Kernel::Config')->Get('ScriptAlias');

        # Navigate to AgentITSMChangeZoom of created test change.
        $Selenium->VerifiedGet("${ScriptAlias}index.pl?Action=AgentITSMChangeZoom;ChangeID=$ChangeID");

        # Click on 'Edit' and switch screens.
        $Selenium->find_element("//a[contains(\@href, \'Action=AgentITSMChangeHistory;ChangeID=$ChangeID' )]")->click();

        $Selenium->WaitFor( WindowCount => 2 );
        my $Handles = $Selenium->get_window_handles();
        $Selenium->switch_to_window( $Handles->[1] );

        # Wait until page has loaded, if necessary.
        $Selenium->WaitFor( JavaScript => 'return typeof($) === "function" && $(".CancelClosePopup").length' );

        # Click on history show details to check AgentITSMChangeHistoryZoom screen.
        $Selenium->find_element("//a[contains(\@href, \'Action=AgentITSMChangeHistoryZoom;HistoryEntryID=' )]")
            ->VerifiedClick();

        # Check AgentITSMChangeHistoryZoom values.
        $Self->True(
            index( $Selenium->get_page_source(), "Detailed history information of ChangeUpdate" ) > -1,
            "Detailed history information of ChangeUpdate is found",
        );
        $Self->True(
            index( $Selenium->get_page_source(), $ChangeTitleRandom ) > -1,
            "$ChangeTitleRandom is found",
        );

        # Delete test created change.
        my $Success = $ChangeObject->ChangeDelete(
            ChangeID => $ChangeID,
            UserID   => 1,
        );
        $Self->True(
            $Success,
            "$ChangeTitleRandom is deleted",
        );

        # Make sure cache is correct.
        $Kernel::OM->Get('Kernel::System::Cache')->CleanUp( Type => 'ITSMChange*' );
    }
);

1;
