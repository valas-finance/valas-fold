from brownie import *
from constants import *

def test():
    a = accounts[1]
    wbnb = Contract(WBNB_ADDRESS)
    valbnb = Contract(VALBNB_ADDRESS)
    debtbnb = Contract(DEBTBNB_ADDRESS)

    fold = Fold.deploy(PROVIDER_ADDRESS, POOL_ADDRESS, WBNB_ADDRESS, VALBNB_ADDRESS, DEBTBNB_ADDRESS, {'from': a})
    
    wbnb.approve(fold.address, 2**256-1, {'from': a})
    valbnb.approve(fold.address, 2**256-1, {'from': a})
    debtbnb.approveDelegation(fold.address, 2**256-1, {'from': a})

    deposit = 10*UNIT
    assert wbnb.balanceOf(a.address) == 0
    wbnb.deposit({'value': deposit, 'from': a})

    # Simulate loops
    loan = 0
    amount = deposit
    for i in range(5):
        amount = amount*75//100
        loan += amount

    # Fold
    fold.fold(WBNB_ADDRESS, deposit, loan, {'from': a})
    assert wbnb.balanceOf(a.address) == 0
    assert valbnb.balanceOf(a.address) == deposit+loan
    assert debtbnb.balanceOf(a.address) >= loan

    # Make sure there's nothing left in the contract
    assert wbnb.balanceOf(fold.address) == 0
    assert valbnb.balanceOf(fold.address) == 0
    assert debtbnb.balanceOf(fold.address) == 0

    # Unfold
    fold.unfold(WBNB_ADDRESS, VALBNB_ADDRESS, DEBTBNB_ADDRESS, {'from': a})
    bal = wbnb.balanceOf(a.address)
    assert bal > 0 and bal <= deposit
    assert valbnb.balanceOf(a.address) == 0
    assert debtbnb.balanceOf(a.address) == 0

    # Make sure there's nothing left in the contract
    assert wbnb.balanceOf(fold.address) == 0
    assert valbnb.balanceOf(fold.address) == 0
    assert debtbnb.balanceOf(fold.address) == 0
